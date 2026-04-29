# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

A single-cluster homelab forked from `onedr0p/cluster-template`. It provisions a Talos Linux Kubernetes cluster managed via Flux (GitOps) on bare-metal/VM nodes, with secrets encrypted by SOPS+age and external access via Cloudflare Tunnel.

The repo is still in "templated" mode: `cluster.yaml` + `nodes.yaml` are rendered by `makejinja` (using files in `templates/`) into the concrete configs under `kubernetes/`, `talos/`, and `bootstrap/`. Once the cluster is stable, `task template:tidy` removes the template plumbing.

## Tooling

All CLIs are pinned in `.mise.toml`. Activate with `mise install` after `mise trust`. Notable: `talhelper`, `talosctl`, `flux`, `helmfile`, `kustomize`, `sops`, `age`, `cue`, `kubeconform`, `cloudflared`, `makejinja` (via pipx), Python 3.14 in `.venv`.

Environment variables are auto-set by mise:
- `KUBECONFIG=./kubeconfig`
- `TALOSCONFIG=./talos/clusterconfig/talosconfig`
- `SOPS_AGE_KEY_FILE=./age.key`
- `SOPS_CONFIG=./.sops.yaml`

## Common commands

Run via [Task](https://taskfile.dev) (`task --list` for everything):

```sh
# Template / lifecycle
task init                        # rename *.sample.yaml, generate age key + deploy key + push token
task configure                   # validate cluster.yaml/nodes.yaml, render templates, encrypt SOPS files, run kubeconform + talhelper validate
task template:tidy               # archive template machinery once cluster is stable

# Bootstrap (one-time)
task bootstrap:talos             # gensecret -> genconfig -> apply --insecure -> bootstrap -> fetch kubeconfig
task bootstrap:apps              # scripts/bootstrap-apps.sh: namespaces, SOPS secrets, CRDs (helmfile 00-crds.yaml), helm releases (01-apps.yaml)

# Day-2 Talos / Kubernetes
task talos:generate-config       # re-render Talos machine configs from talconfig.yaml
task talos:apply-node IP=<ip> [MODE=auto|reboot|staged|try]
task talos:upgrade-node IP=<ip>  # uses .talosImageURL from talconfig.yaml + talosVersion from talenv.yaml
task talos:upgrade-k8s           # uses kubernetesVersion from talenv.yaml
task talos:reset                 # destructive — wipes nodes back to maintenance

# Flux
task reconcile                   # flux reconcile kustomization flux-system --with-source
task template:debug              # dump common cluster resources

# Validation (also run inside `task configure`)
cue vet cluster.yaml .taskfiles/template/resources/cluster.schema.cue
cue vet nodes.yaml   .taskfiles/template/resources/nodes.schema.cue
bash .taskfiles/template/resources/kubeconform.sh kubernetes
talhelper validate talconfig talos/talconfig.yaml
```

There is no application test suite — validation here is `cue vet`, `kubeconform`, `talhelper validate`, and `flux check`. End-to-end CI lives in `.github/workflows/e2e.yaml` and `flux-local.yaml`.

## Architecture

### Templating layer (`templates/` + `makejinja.toml`)

`task configure` runs `makejinja` with non-default Jinja delimiters (`#% %#`, `#{ }#`, `#| |#`) so rendered YAML stays valid before rendering. Inputs:
- `cluster.yaml` — cluster-wide values (CIDRs, gateway IPs, Cloudflare domain, etc.). Schema: `.taskfiles/template/resources/cluster.schema.cue`.
- `nodes.yaml` — per-node hostname/IP/MAC/disk selectors. Schema: `.taskfiles/template/resources/nodes.schema.cue`.
- `templates/scripts/plugin.py` — custom Jinja filters loaded via `loaders = ["plugin:Plugin"]`.
- `templates/config/{bootstrap,kubernetes,talos}/**/*.j2` — sources rendered into the same paths at the repo root.
- `templates/overrides/` — wins over `templates/config/`.

After rendering, `task configure` SOPS-encrypts every `*.sops.*` file under `bootstrap/`, `kubernetes/`, `talos/` that isn't already encrypted. Never commit those files unencrypted.

### Talos layer (`talos/`)

`talconfig.yaml` (rendered) is consumed by `talhelper genconfig` to produce `talos/clusterconfig/*.yaml` and `talos/clusterconfig/talosconfig`. `talsecret.sops.yaml` holds the cluster's PKI; it is generated once during `task bootstrap:talos` and must remain encrypted. `talenv.yaml` carries `talosVersion` / `kubernetesVersion` consumed by upgrade tasks. CNI is disabled in Talos (`cniConfig.name: none`) — Cilium is installed by the bootstrap-apps step.

### Bootstrap layer (`bootstrap/` + `scripts/bootstrap-apps.sh`)

`bootstrap-apps.sh` runs once after Talos is up to seed the cluster before Flux can take over:
1. Wait for nodes to reach `Ready=False` (CNI not yet present).
2. `kubectl create namespace` for each `kubernetes/apps/*/` directory.
3. Apply three SOPS-encrypted bootstrap secrets (deploy key, age key as a Secret for Flux, cluster-secrets).
4. `helmfile template` `bootstrap/helmfile.d/00-crds.yaml` and apply only `CustomResourceDefinition` objects.
5. `helmfile sync` `bootstrap/helmfile.d/01-apps.yaml` to install Cilium, CoreDNS, Spegel, and Flux itself.

After this, Flux reconciles the rest from Git.

### GitOps layer (`kubernetes/`)

Flux entrypoint: `kubernetes/flux/cluster/ks.yaml`. It defines a single root `Kustomization` (`cluster-apps`) that points at `./kubernetes/apps` and uses Kustomize patches to inject sane defaults into every child `Kustomization` and `HelmRelease` (SOPS decryption, `WaitForTermination`, `RetryOnFailure`, `RemediateOnFailure` with 2 retries, `crds: CreateReplace`). When adding a new `Kustomization`/`HelmRelease`, do **not** re-specify these defaults — let the root patch supply them.

Directory convention under `kubernetes/apps/<namespace>/`:
- `namespace.yaml` + `kustomization.yaml` at the namespace root.
- One subdirectory per app: `<app>/ks.yaml` (Flux Kustomization) + `<app>/app/` (HelmRelease, OCIRepository, supporting manifests, `kustomization.yaml`).
- Each `ks.yaml` typically uses `postBuild.substituteFrom: cluster-secrets` so `${var}` placeholders in app manifests get filled from the SOPS-encrypted `cluster-secrets` Secret.

Currently deployed namespaces: `flux-system`, `kube-system` (cilium, coredns, reloader, spegel, metrics-server), `cert-manager`, `network` (envoy-gateway, k8s-gateway, cloudflare-dns, cloudflare-tunnel), `openebs-system`, `default`.

`kubernetes/components/sops/` is a Kustomize component referenced by child Kustomizations that need the cluster-wide secrets envelope.

### Secrets (`.sops.yaml`)

Two creation rules:
- `talos/*.sops.yaml` — whole-file encryption (`mac_only_encrypted: true`).
- `bootstrap/*.sops.*` and `kubernetes/*.sops.*` — partial: `encrypted_regex: ^(data|stringData)$` so only Secret payloads are encrypted; metadata stays diff-friendly.

Both rules use the single age recipient in `.sops.yaml`. The matching private key is `age.key` (gitignored). Never weaken `encrypted_regex` or remove `mac_only_encrypted` without intent — both are required for clean diffs and `task configure` re-encryption to be idempotent.

## Conventions when editing

- New Helm-based app → add `kubernetes/apps/<ns>/<app>/{ks.yaml,app/{helmrelease.yaml,ocirepository.yaml,kustomization.yaml}}` mirroring an existing app like `kubernetes/apps/openebs-system/openebs/`. Reference the OCIRepository from the HelmRelease via `chartRef`, not chart name + version.
- Renovate (`.renovaterc.json5`) drives image/chart bumps; prefer letting it open the PR for version updates rather than hand-editing pinned tags.
- File paths under `kubernetes/`, `talos/`, and `bootstrap/` may be templated outputs. If a `.j2` source exists in `templates/`, edit the source unless `task template:tidy` has already been run (check whether `templates/` and `makejinja.toml` still exist).
- Touching CRDs that need to be present before the controller starts? Add them to `bootstrap/helmfile.d/00-crds.yaml`, not `01-apps.yaml`.
