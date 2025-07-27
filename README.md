# 🏠 Neil's Homelab Infrastructure

<div align="center">

[![Talos](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.npmulder.dev%2Ftalos_version&style=for-the-badge&logo=talos&logoColor=white&color=blue&label=%20)](https://talos.dev)&nbsp;&nbsp;
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.npmulder.dev%2Fkubernetes_version&style=for-the-badge&logo=kubernetes&logoColor=white&color=blue&label=%20)](https://kubernetes.io)&nbsp;&nbsp;
[![Flux](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.npmulder.dev%2Fflux_version&style=for-the-badge&logo=flux&logoColor=white&color=blue&label=%20)](https://fluxcd.io)&nbsp;&nbsp;

</div>

<div align="center">

[![Status-Page](https://img.shields.io/uptimerobot/status/m793599155-ba1b18e51c9f8653acd0f5c1?color=brightgreeen&label=Status%20Page&style=for-the-badge&logo=statuspage&logoColor=white)](https://status.npmulder.dev)&nbsp;&nbsp;
[![Alertmanager](https://img.shields.io/uptimerobot/status/m793494864-dfc695db066960233ac70f45?color=brightgreeen&label=Alertmanager&style=for-the-badge&logo=prometheus&logoColor=white)](https://status.npmulder.dev)

</div>

<div align="center">

[![Age-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.npmulder.dev%2Fcluster_age_days&style=flat-square&label=Age)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Uptime-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.npmulder.dev%2Fcluster_uptime_days&style=flat-square&label=Uptime)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Node-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.npmulder.dev%2Fcluster_node_count&style=flat-square&label=Nodes)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Pod-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.npmulder.dev%2Fcluster_pod_count&style=flat-square&label=Pods)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![CPU-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.npmulder.dev%2Fcluster_cpu_usage&style=flat-square&label=CPU)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Memory-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.npmulder.dev%2Fcluster_memory_usage&style=flat-square&label=Memory)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Alerts](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.npmulder.dev%2Fcluster_alert_count&style=flat-square&label=Alerts)](https://github.com/kashalls/kromgo)

</div>

---

Welcome to my homelab! This repository contains my complete **GitOps-driven** Kubernetes infrastructure running on **Talos Linux**. Everything is declarative, automated, and immutable - exactly how modern infrastructure should be.

## 📖 Overview

This homelab showcases **enterprise-grade practices** in a home environment, featuring:
- **Immutable infrastructure** with Talos Linux
- **GitOps workflow** using Flux CD
- **Comprehensive monitoring** with Prometheus and Grafana
- **Automated dependency management** via Renovate
- **Security-first approach** with encrypted secrets and network policies

The entire cluster is managed through Git - no manual kubectl commands, no SSH access, no exceptions.

## ⚡ Technology Stack

<table>
  <tr>
    <th>Component</th>
    <th>Technology</th>
    <th>Purpose</th>
  </tr>
  <tr>
    <td><strong>Operating System</strong></td>
    <td><a href="https://www.talos.dev/">Talos Linux</a></td>
    <td>API-driven, immutable Kubernetes OS</td>
  </tr>
  <tr>
    <td><strong>GitOps</strong></td>
    <td><a href="https://fluxcd.io/">Flux CD</a></td>
    <td>Continuous delivery and cluster synchronization</td>
  </tr>
  <tr>
    <td><strong>Container Network</strong></td>
    <td><a href="https://cilium.io/">Cilium</a></td>
    <td>eBPF-based networking with BGP support</td>
  </tr>
  <tr>
    <td><strong>Storage</strong></td>
    <td><a href="https://openebs.io/">OpenEBS</a></td>
    <td>Local persistent storage with hostPath provisioner</td>
  </tr>
  <tr>
    <td><strong>Secret Management</strong></td>
    <td><a href="https://github.com/getsops/sops">SOPS</a> + <a href="https://github.com/FiloSottile/age">Age</a></td>
    <td>Encrypted secrets in Git</td>
  </tr>
  <tr>
    <td><strong>Certificates</strong></td>
    <td><a href="https://cert-manager.io/">cert-manager</a></td>
    <td>Automated Let's Encrypt certificates</td>
  </tr>
  <tr>
    <td><strong>Ingress</strong></td>
    <td><a href="https://nginx.org/en/">NGINX</a> + <a href="https://www.cloudflare.com/products/tunnel/">Cloudflare Tunnel</a></td>
    <td>Internal and external application access</td>
  </tr>
  <tr>
    <td><strong>Monitoring</strong></td>
    <td><a href="https://prometheus.io/">Prometheus</a> + <a href="https://grafana.com/">Grafana</a></td>
    <td>Metrics collection and visualization</td>
  </tr>
  <tr>
    <td><strong>Logging</strong></td>
    <td><a href="https://grafana.com/oss/loki/">Loki</a> + <a href="https://grafana.com/docs/loki/latest/clients/promtail/">Promtail</a></td>
    <td>Centralized log aggregation</td>
  </tr>
</table>

## 🎯 Key Features

- **🔒 Immutable Infrastructure**: Zero SSH access, all changes via GitOps
- **🤖 Automated Everything**: Renovate handles dependency updates
- **📊 Enterprise Monitoring**: 20+ Grafana dashboards with comprehensive alerting
- **🔐 Security First**: Encrypted secrets, network policies, security contexts
- **🎭 High Availability**: 3-node control plane with local persistent storage
- **🚀 Zero Downtime**: Rolling updates with proper health checks
- **🌐 Hybrid Networking**: Internal and external application access

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        🌐 Internet                              │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                   ☁️  Cloudflare                                │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                   │
│  │   DNS & Proxy   │    │   Zero Trust    │                   │
│  │                 │    │     Tunnel      │                   │
│  └─────────────────┘    └─────────────────┘                   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                   🏠 Homelab Network                            │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │   Talos Node    │    │   Talos Node    │    │ Talos Node  │ │
│  │  (Control+Work) │    │  (Control+Work) │    │(Control+Work)│ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                 📦 Kubernetes Cluster                      │ │
│  │                                                             │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐          │ │
│  │  │   Media     │ │ Monitoring  │ │  Networking │          │ │
│  │  │   Stack     │ │    Stack    │ │    Stack    │          │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘          │ │
│  │                                                             │ │
│  │  ┌─────────────────────────────────────────────────────────┐ │ │
│  │  │              🗄️  OpenEBS Local Storage                │ │ │
│  │  └─────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Getting Started

### Prerequisites

```bash
# Install development tools
mise trust && mise install

# Bootstrap the cluster
task bootstrap:talos        # Install Talos Linux
task bootstrap:apps         # Deploy applications
```

### Daily Operations

```bash
# Monitor cluster health
kubectl get pods -A --watch
cilium status
flux get hr -A

# Force synchronization
task reconcile

# View logs
kubectl logs -n <namespace> <pod> -f
```

## 📁 Repository Structure

```
📁 homelab/
├── 🔧 bootstrap/                 # Initial cluster setup
├── 📁 kubernetes/
│   ├── 📁 apps/                  # Applications by namespace
│   │   ├── 📁 cert-manager/      # Certificate management
│   │   ├── 📁 default/           # Media applications
│   │   ├── 📁 network/           # Ingress, DNS, tunnels
│   │   ├── 📁 observability/     # Monitoring stack
│   │   └── 📁 openebs-system/    # Local storage provisioner
│   ├── 📁 components/            # Reusable components
│   └── 📁 flux/                  # GitOps configuration
├── 📁 talos/                     # OS configuration
└── 📁 scripts/                   # Automation scripts
```

## 🔧 Application Highlights

### 📺 Media Stack
- **Sonarr/Radarr**: Automated TV show and movie management
- **Prowlarr**: Indexer management
- **Plex**: Media server with hardware transcoding

### 📊 Monitoring Stack
- **Prometheus**: Metrics collection with 20+ pre-configured alerts
- **Grafana**: 20+ dashboards covering infrastructure and applications
- **Loki**: Centralized logging with retention policies
- **Alertmanager**: Multi-channel alerting (Discord, email)

### 🌐 Networking
- **Internal Access**: k8s-gateway for local DNS resolution
- **External Access**: Cloudflare Tunnel for secure remote access
- **Load Balancing**: NGINX ingress controllers
- **Network Security**: Cilium network policies

### 🗄️ Storage
- **Local Storage**: OpenEBS hostPath provisioner for persistent volumes
- **Media Storage**: NFS integration with TrueNAS for media files
- **AI Workloads**: Dedicated storage for Ollama models and inference

## 🎨 Configuration Management

Every application follows a consistent pattern:

```
app/
├── helmrelease.yaml      # Helm chart deployment
├── kustomization.yaml    # Kustomize configuration
├── externalsecret.yaml   # SOPS-encrypted secrets
└── resources/            # Additional K8s resources
```

## 🔒 Security Features

- **🔐 Encrypted Secrets**: All sensitive data encrypted with SOPS + Age
- **🛡️ Network Policies**: Micro-segmentation with Cilium
- **📜 Security Contexts**: Non-root containers with minimal privileges
- **🔒 Pod Security Standards**: Enforced security policies
- **🌐 Zero Trust**: Cloudflare Access for external services

## 🤖 Automation

### Renovate Configuration
- **Automated Updates**: Container images, Helm charts, GitHub Actions
- **Grouped Dependencies**: Related updates bundled together
- **Scheduled Updates**: Weekend update cycles
- **Pre-commit Validation**: flux-local ensures manifests are valid

### CI/CD Pipeline
- **Manifest Validation**: Pre-commit hooks with flux-local
- **Diff Generation**: Automated PR comments showing changes
- **Security Scanning**: SOPS validation for encrypted secrets

## 📈 Monitoring & Observability

### Grafana Dashboards
- **Infrastructure**: Node metrics, storage, networking
- **Applications**: Application-specific metrics and health
- **Kubernetes**: Cluster resources and workload status
- **Media Stack**: Download statistics and performance

### Alerting
- **Infrastructure Alerts**: Node down, disk space, memory usage
- **Application Alerts**: Pod crashes, certificate expiry
- **Network Alerts**: Ingress failures, DNS resolution issues

## 🧪 Development Workflow

1. **Local Changes**: Edit manifests in your IDE
2. **Validation**: `flux-local` validates changes locally
3. **Git Push**: Changes pushed to repository
4. **Automatic Sync**: Flux applies changes to cluster
5. **Monitoring**: Grafana dashboards show deployment status

## 🔧 Troubleshooting

### Common Commands

```bash
# Flux troubleshooting
flux check
flux get sources git -A
flux get ks -A
flux get hr -A

# Application debugging
kubectl -n <namespace> describe pod <pod-name>
kubectl -n <namespace> logs <pod-name> -f
kubectl -n <namespace> get events --sort-by='.metadata.creationTimestamp'

# Network debugging
cilium status
nmap -Pn -n -p 443 <ingress-ip>
```

### Resource Recovery

```bash
# Force reconciliation
task reconcile

# Restart failed pods
kubectl -n <namespace> rollout restart deployment <deployment>

# Certificate issues
kubectl -n cert-manager describe certificates
```

## 🙏 Inspiration & Thanks

This homelab draws inspiration from the amazing Kubernetes at Home community:

- [**onedr0p/home-ops**](https://github.com/onedr0p/home-ops) - The gold standard for homelab GitOps
- [**bjw-s/home-ops**](https://github.com/bjw-s/home-ops) - Excellent patterns and practices
- [**k8s-at-home/charts**](https://github.com/k8s-at-home/charts) - Community Helm charts
- [**Home Operations Discord**](https://discord.gg/home-operations) - Incredibly helpful community

## 📊 Repository Statistics

![Repository Stats](https://repobeats.axiom.co/api/embed/58f29dbece9f9142eec77ad7f9000d7689e6990c.svg "Repobeats analytics image")

---

<div align="center">

**⭐ If you find this repository helpful, please consider giving it a star!**

*Built with ❤️ using GitOps principles and powered by the Kubernetes at Home community*

</div>