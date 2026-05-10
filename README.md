# Homelab Infrastructure as Code

> A production-grade homelab managed entirely through code — provisioning, configuration, and secrets handled with the same rigour as a professional cloud environment.

---

## Overview

This repository contains the full Infrastructure as Code (IaC) for a two-node Proxmox homelab. Every resource is defined declaratively, every secret is encrypted at rest, and every change goes through automated validation before being applied.

**This project serves as a live portfolio demonstrating:**
- GitOps and IaC discipline on real hardware
- Security-first secret management (zero plaintext secrets in git)
- Multi-layer infrastructure automation (provisioning → configuration → orchestration)

---

## Stack

| Layer | Tool | Purpose |
|---|---|---|
| Provisioning | OpenTofu + Terragrunt | Proxmox LXCs, VMs, networking |
| Configuration | Ansible | OS hardening, service deployment |
| Secret Management | SOPS + Age | Encrypted secrets committed safely |
| Container Orchestration | K3s | Lightweight Kubernetes (almond + peanut) |
| Container Orchestration | Kubeadm | Full Kubernetes (almond, HA control plane) |
| CI/CD | GitHub Actions | Validate, lint, plan on every PR |
| Remote State | S3-compatible (Minio) | State stored off-repo, never local |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        Homelab Network                            │
│                                                                   │
│  ┌────────────────────────────┐  ┌────────────────────────────┐  │
│  │  almond                    │  │  peanut                    │  │
│  │  AMD Ryzen 7 5800X / 64GB  │  │  AMD Ryzen 5 3600 / 32GB   │  │
│  │                            │  │                            │  │
│  │  LXCs:                     │  │  LXCs:                     │  │
│  │  ├─ cloudflared            │  │  ├─ nginxproxymanager ◄─┐  │  │
│  │  ├─ wireguard              │  │  ├─ adguard              │  │  │
│  │  ├─ postgres               │  │  ├─ homarr               │  │  │
│  │  ├─ minecraft              │  │  └─ postgres-replica     │  │  │
│  │  ├─ coder-server           │  │                          │  │  │
│  │  └─ ttyd                   │  │  VMs:                    │  │  │
│  │                            │  │  ├─ k3s (K3s agent) ─────┼──┼──┐
│  │  VMs:                      │  │  ├─ TrueNAS              │  │  ││
│  │  ├─ kadm-master (K8s CP)   │  │  ├─ Home Assistant OS    │  │  ││
│  │  ├─ kadm-w1 (K8s worker)   │  │  └─ kubeadm-h2 (K8s)    │  │  ││
│  │  ├─ kubeadm-deb (K8s wkr)  │  └────────────────────────────┘  ││
│  │  ├─ k3s-ha ────────────────┼──────────────────────────────────┼┼┐
│  │  └─ docker                 │                                   │││
│  └────────────────────────────┘                                   │││
└──────────────────────────────────────────────────────────────────┘│││
                                                                     │││
┌────────────────────────────────────────────────────────────────┐  │││
│  OVH Cloud — Madrid LocalZone (MAD1)    [IPs encrypted/private] │  │││
│                                                                  │  │││
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │  │││
│  │vps-6b58f204 │  │vps-04483f6e │  │vps-d147fb4d │            │  │││
│  │4vCPU/8GB/75G│  │4vCPU/8GB/75G│  │4vCPU/8GB/75G│            │  │││
│  │AMD EPYC Gen │  │AMD EPYC Gen │  │AMD EPYC Gen │            │  │││
│  │Created:     │  │WireGuard hub│  │ArgoCD ctrl  │            │  │││
│  │2025-11-15   │  │wg-easy      │  │Grafana       │            │  │││
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘            │  │││
│         └────────────────┴─────────────────┘                   │  │││
│                 K3s HA v1.33.5 (etcd distributed) ◄────────────┼──┘││
│                 Traefik · cert-manager · Longhorn               │   ││
│                 Matrix Synapse · CloudNativePG · Redis HA       │   ││
│                 Grafana · InfluxDB · Mosquitto · frps           │   ││
└────────────────────────────────────────────────────────────────┘   ││
                                                                      ││
┌────────────────────────────────────────────────────────────────┐   ││
│  OVH Cloud — Gravelines GRA8            [IP encrypted/private]  │   ││
│                                                                  │   ││
│  vps-f24bf8b4  AMD EPYC Milan  2vCPU / 2GB / 40GB              │   ││
│  Debian 12 · Created: 2023-08-28                                │   ││
│                                                                  │   ││
│  ├─ HAProxy L4/L7 ──────────────────────────────────────────────┼───┘│
│  │   :80/:443  → nginxproxymanager (peanut LXC)                 │    │
│  │   :6443     → kubeadm API server (almond)                    │    │
│  │   :25565/6  → minecraft (almond LXC)                         │    │
│  │   :51820    → TrueNAS (via Tailscale)                        │    │
│  ├─ Redis (localhost)                                            │    │
│  ├─ Tailscale mesh (100.122.164.104)                            │    │
│  ├─ WireGuard wg0 (10.10.0.3/24)                               │    │
│  └─ Zabbix agent                                                │    │
└────────────────────────────────────────────────────────────────┘    │
                                                                       │
                        K3s agent (peanut/k3s VM) joins MAD cluster ──┘
```

> All public IPs are stored encrypted via SOPS+Age and never appear in plaintext in this repository.

---

## Repository Structure

```
homelab/
├── .github/
│   └── workflows/
│       └── validate.yml        # Terragrunt validate + Ansible lint on every PR
├── .sops.yaml                  # SOPS encryption rules (public keys only)
├── .gitignore                  # Hardened to prevent any secret leakage
│
├── infrastructure/
│   └── tofu/
│       ├── live/               # Terragrunt live configurations (per node)
│       │   ├── terragrunt.hcl  # Root config: remote state, providers, SOPS
│       │   ├── almond/
│       │   │   ├── region.hcl              # Non-sensitive node config
│       │   │   ├── secrets.sops.json       # Encrypted secrets (safe to commit)
│       │   │   ├── lxc/terragrunt.hcl      # minecraft, wireguard, postgres, ...
│       │   │   ├── vms/terragrunt.hcl      # kadm-master, k3s-ha, docker, ...
│       │   │   └── k3s/terragrunt.hcl
│       │   └── peanut/
│       │       ├── region.hcl
│       │       ├── secrets.sops.json
│       │       ├── lxc/terragrunt.hcl      # nginxproxymanager, adguard, homarr, ...
│       │       ├── vms/terragrunt.hcl      # k3s, TrueNAS, haos, kubeadm-h2
│       │       └── kubeadm/terragrunt.hcl
│       └── modules/            # Reusable OpenTofu modules
│           ├── proxmox-lxc/
│           ├── proxmox-vm/
│           ├── k3s-cluster/
│           ├── kubeadm-cluster/
│           └── networking/
│
├── ansible/
│   ├── ansible.cfg             # SOPS vars plugin enabled
│   ├── inventories/
│   │   ├── pve-node-01/hosts.yml
│   │   └── pve-node-02/hosts.yml
│   ├── group_vars/
│   │   └── all/
│   │       ├── vars.yml        # Non-sensitive shared variables
│   │       └── vault.sops.yml  # Encrypted secrets (auto-decrypted by Ansible)
│   ├── roles/
│   │   ├── common/             # OS hardening, packages, NTP
│   │   ├── proxmox-baseline/   # Proxmox-specific config
│   │   ├── k3s-node/           # K3s installation and config
│   │   └── kubeadm-node/       # Kubeadm installation and config
│   └── playbooks/
│       └── site.yml            # Master playbook
│
├── scripts/
│   ├── age-keygen.sh           # One-time Age keypair generation
│   ├── sops-encrypt.sh         # Encrypt a plaintext file via SOPS
│   └── validate.sh             # Pre-commit secret leak validation
│
└── docs/
    ├── architecture.md
    └── runbooks.md
```

---

## Secret Management

All secrets are encrypted using [SOPS](https://github.com/getsops/sops) + [Age](https://github.com/FiloSottile/age) before being committed. **No plaintext secrets exist anywhere in this repository.**

### How It Works

```
Developer                    Repository                    Runtime
─────────                    ──────────                    ───────
plaintext secret             secrets.sops.json             sops --decrypt
     │                            │                              │
     └──► sops --encrypt ────────►│◄──── Terragrunt/Ansible ────┘
          (age public key)        │      (age private key,
                                  │       env var only)
```

- **Terragrunt** calls `sops_decrypt_file()` natively — secrets are never written to disk.
- **Ansible** uses the `community.sops` vars plugin — `vault.sops.yml` files are decrypted in memory at play time.
- **CI/CD** receives the age private key via a GitHub Actions secret (`SOPS_AGE_KEY`) — it never touches the repo.

### First-Time Setup

```bash
# 1. Generate your age keypair
./scripts/age-keygen.sh

# 2. Add your public key to .sops.yaml

# 3. Create and encrypt your secrets
cp infrastructure/tofu/live/pve-node-01/secrets.sops.json.example \
   infrastructure/tofu/live/pve-node-01/secrets.json
# ... fill in real values ...
./scripts/sops-encrypt.sh infrastructure/tofu/live/pve-node-01/secrets.json

# 4. Edit encrypted secrets any time
sops infrastructure/tofu/live/pve-node-01/secrets.sops.json
```

---

## Workflows

### Provision Infrastructure

```bash
# Plan changes for a specific component
cd infrastructure/tofu/live/pve-node-01/lxc
terragrunt plan

# Apply all components on a node
cd infrastructure/tofu/live/pve-node-01
terragrunt run-all apply

# Apply everything (all nodes)
cd infrastructure/tofu/live
terragrunt run-all apply
```

### Configure with Ansible

```bash
# Run full site playbook
ansible-playbook -i ansible/inventories/pve-node-01 ansible/playbooks/site.yml

# Run only a specific role
ansible-playbook -i ansible/inventories/pve-node-01 ansible/playbooks/site.yml \
  --tags k3s
```

### Validate Before Committing

```bash
# Check for secret leaks and format issues
./scripts/validate.sh
```

---

## CI/CD

Every pull request triggers:

1. **Secret leak scan** — `scripts/validate.sh` runs against all tracked files
2. **Terragrunt validate** — all modules are initialised and validated (uses SOPS via `SOPS_AGE_KEY` secret)
3. **Ansible lint** — all playbooks are linted with `ansible-lint`

Merges to `main` are blocked until all checks pass.

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| OpenTofu | >= 1.7 | [opentofu.org](https://opentofu.org) |
| Terragrunt | >= 0.58 | [terragrunt.gruntwork.io](https://terragrunt.gruntwork.io) |
| Ansible | >= 2.16 | `pip install ansible` |
| SOPS | >= 3.8 | [github.com/getsops/sops](https://github.com/getsops/sops) |
| age | >= 1.1 | `brew install age` |
| community.sops | >= 0.19 | `ansible-galaxy collection install community.sops` |

---

## License

MIT — feel free to fork and adapt for your own homelab.

---

> **Portfolio note:** This repository demonstrates real infrastructure patterns used in production cloud environments, applied to on-premises hardware. The same principles (GitOps, least-privilege secrets, immutable infrastructure, idempotent automation) apply at any scale.
