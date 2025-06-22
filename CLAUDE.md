# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Kubernetes homelab infrastructure project using Talos Linux as the immutable OS and Flux CD for GitOps. The cluster runs on bare-metal with enterprise-grade practices including comprehensive monitoring, automated dependency management, and security hardening.

## Development Environment

### Setup
```bash
mise trust              # Trust mise configuration
mise install            # Install all required tools (kubectl, helm, flux, talos, age, sops, etc.)
```

### Core Technologies
- **Talos Linux**: Immutable Kubernetes OS 
- **Flux CD**: GitOps continuous delivery
- **Cilium**: CNI with BGP support for UniFi integration
- **Helm + Kustomize**: Hybrid configuration management
- **SOPS + Age**: Secret encryption and management
- **Rook-Ceph**: Distributed storage

## Common Commands

### Core Operations
```bash
task reconcile              # Force Flux to sync Git repository
task bootstrap:talos        # Bootstrap Talos cluster
task bootstrap:apps         # Bootstrap applications after Talos
task talos:reset           # Reset cluster to maintenance mode
task talos:upgrade-node IP=<ip>  # Upgrade specific Talos node
task talos:upgrade-k8s     # Upgrade Kubernetes version
task configure             # Template out configurations from cluster.yaml/nodes.yaml
```

### Flux Operations
```bash
flux check                 # Validate Flux installation
flux get sources git -A    # Check Git sources
flux get ks -A            # Check Kustomizations
flux get hr -A            # Check Helm releases
```

### Development & Testing
```bash
flux-local                 # Local Flux testing and diff generation (used in CI)
cilium status             # Check Cilium networking status
kubectl get pods --all-namespaces --watch  # Monitor cluster rollout
```

## Architecture & Directory Structure

### Application Structure Pattern
Each application follows this standard structure:
```
app/
├── helmrelease.yaml      # Helm deployment
├── kustomization.yaml    # Kustomize configuration  
├── externalsecret.yaml   # Secret management (optional)
├── helm/values.yaml      # Helm values (optional)
└── resources/            # Additional resources (optional)
```

### Key Directories
- `kubernetes/apps/`: Applications organized by namespace (cert-manager, default, network, observability, etc.)
- `kubernetes/components/`: Reusable Kustomize components
- `kubernetes/flux/`: Flux CD configuration and cluster sync
- `talos/`: Talos Linux configuration and patches
- `bootstrap/`: Initial cluster bootstrap with Helmfile
- `scripts/`: Automation scripts

### Namespace Organization
- `cert-manager`: Certificate management with Let's Encrypt
- `default`: Media apps (Sonarr, Prowlarr, etc.)
- `external-secrets`: Secret management integration
- `kube-system`: Core system components (Cilium, CoreDNS)
- `network`: Ingress controllers, DNS, Cloudflare tunnel
- `observability`: Prometheus stack, Grafana, Loki
- `rook-ceph`: Distributed storage
- `volsync-system`: Volume synchronization

## Development Patterns

### Adding New Applications
1. Create namespace directory under `kubernetes/apps/`
2. Follow standard app structure pattern
3. Use `ExternalSecret` + SOPS for sensitive data
4. Configure appropriate ingress class (`internal` or `external`)
5. Add `ServiceMonitor` for Prometheus scraping if applicable
6. Use Rook-Ceph `PersistentVolumes` for storage needs

### Secret Management
- All secrets encrypted with SOPS using Age keys
- Use `ExternalSecret` resources pointing to OnePassword
- Never commit unencrypted secrets
- Verify `*.sops.*` files are encrypted before committing

### Networking Configuration
- **Internal apps**: Use `internal` ingress class 
- **External apps**: Use `external` ingress class with Cloudflare tunnel
- **DNS**: k8s-gateway handles internal resolution, external-dns manages Cloudflare
- **Security**: Cilium NetworkPolicies for traffic control

### Monitoring & Observability
- Prometheus stack with 20+ pre-configured Grafana dashboards
- Loki + Promtail for centralized logging
- Add `ServiceMonitor` resources for new applications
- Use comprehensive resource limits and security contexts

## Security Practices

### Resource Configuration
- Always specify resource limits and requests
- Use restricted security contexts (`runAsNonRoot: true`, etc.)
- Apply least-privilege RBAC policies
- Enable Pod Security Standards where applicable

### Infrastructure Security
- Immutable OS with Talos Linux
- Encrypted secrets at rest with SOPS
- Network segmentation with Cilium policies
- Certificate automation with cert-manager

## CI/CD & Automation

### GitHub Actions
- **flux-local**: Pre-commit validation of Kubernetes manifests
- **Diff Generation**: Automated PR comments showing manifest changes
- **Label Management**: Automated issue/PR labeling

### Renovate Configuration
- Automated updates for container images, Helm charts, GitHub Actions
- Grouped updates for related dependencies  
- Semantic commit messages with proper formatting
- Scheduled updates every weekend (configurable)

## Debugging Common Issues

### Flux Troubleshooting
```bash
task reconcile                    # Force sync
flux get sources git -A           # Check source status
flux get ks -A                   # Check Kustomization status
flux get hr -A                   # Check HelmRelease status
kubectl -n flux-system describe gitrepository flux-system
```

### Application Debugging
```bash
kubectl -n <namespace> get pods -o wide
kubectl -n <namespace> logs <pod-name> -f
kubectl -n <namespace> describe <resource> <name>
kubectl -n <namespace> get events --sort-by='.metadata.creationTimestamp'
```

### Network & DNS Issues
```bash
cilium status                     # Check CNI status
nmap -Pn -n -p 443 <ingress-ip>  # Test ingress connectivity  
dig @<dns-gateway> <domain>      # Test DNS resolution
kubectl -n cert-manager describe certificates  # Check certificate status
```

## Important Notes

- **Immutable Infrastructure**: All changes via GitOps, no manual cluster modifications
- **High Availability**: 3-node control plane for production resilience  
- **Storage**: Rook-Ceph provides replicated block and file storage
- **Updates**: Renovate handles automated dependency management
- **Security**: Enterprise-grade practices with comprehensive monitoring
- **Documentation**: Each major component has specific README files for detailed configuration