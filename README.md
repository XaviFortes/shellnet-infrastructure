# homelab

My personal homelab IaC — two Proxmox nodes at home and a few OVH VPS managed with OpenTofu + Terragrunt + Ansible. Everything is defined as code, secrets are SOPS-encrypted, and nothing with a real value ever gets committed in plaintext.

I built this to stop managing things manually and to have a reproducible setup I can share or rebuild from scratch if needed. If you're doing something similar, feel free to take whatever's useful.

---

## Stack

| Layer | Tool | Purpose |
|---|---|---|
| Provisioning | OpenTofu + Terragrunt | Proxmox LXCs, VMs, OVH VPS |
| Configuration | Ansible | OS config, service deployment |
| Secret Management | SOPS + Age | Encrypted secrets in git |
| Container Orchestration | K3s | Lightweight Kubernetes across VPS + homelab |
| Container Orchestration | Kubeadm | Full K8s control plane on almond |
| CI/CD | GitHub Actions | Validate + plan on every PR |
| Remote State | Backblaze B2 (S3-compatible) | State stored off-repo |

---

## Hardware

```
almond — AMD Ryzen 7 5800X / 64GB RAM / Proxmox 8.4
peanut — AMD Ryzen 5 3600 / 32GB RAM / Proxmox 8.4
```

Both nodes are at home on a private network. Public traffic goes through the OVH GRA bastion (HAProxy).

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
│  │                            │  │  ├─ k3s ─────────────────┼──┼──┐
│  │  VMs:                      │  │  ├─ TrueNAS              │  │  ││
│  │  ├─ kadm-master (K8s CP)   │  │  ├─ Home Assistant OS    │  │  ││
│  │  ├─ kadm-w1 (K8s worker)   │  │  └─ kubeadm-h2           │  │  ││
│  │  ├─ kubeadm-deb            │  └────────────────────────────┘  ││
│  │  ├─ k3s-ha ────────────────┼──────────────────────────────────┼┼┐
│  │  └─ docker                 │                                   │││
│  └────────────────────────────┘                                   │││
└──────────────────────────────────────────────────────────────────┘│││
                                                                     │││
┌────────────────────────────────────────────────────────────────┐  │││
│  OVH Cloud — Madrid LocalZone (MAD1)    [IPs encrypted]         │  │││
│                                                                  │  │││
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │  │││
│  │vps-6b58f204 │  │vps-04483f6e │  │vps-d147fb4d │            │  │││
│  │4vCPU/8GB/75G│  │4vCPU/8GB/75G│  │4vCPU/8GB/75G│            │  │││
│  │AMD EPYC Gen │  │WireGuard hub│  │ArgoCD        │            │  │││
│  │K3s server   │  │wg-easy      │  │Grafana       │            │  │││
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘            │  │││
│         └────────────────┴─────────────────┘                   │  │││
│                 K3s HA v1.33.5 (etcd distributed) ◄────────────┼──┘││
│                 Traefik · cert-manager · Longhorn               │   ││
│                 Matrix Synapse · CloudNativePG · Redis HA       │   ││
│                 Grafana · InfluxDB · Mosquitto · frps           │   ││
└────────────────────────────────────────────────────────────────┘   ││
                                                                      ││
┌────────────────────────────────────────────────────────────────┐   ││
│  OVH Cloud — Gravelines GRA8            [IP encrypted]          │   ││
│                                                                  │   ││
│  vps-f24bf8b4  AMD EPYC Milan  2vCPU / 2GB / 40GB  Debian 12   │   ││
│                                                                  │   ││
│  ├─ HAProxy ────────────────────────────────────────────────────┼───┘│
│  │   :80/:443  → nginxproxymanager (peanut)                     │    │
│  │   :6443     → kubeadm API (almond)                           │    │
│  │   :25565    → minecraft (almond)                             │    │
│  ├─ Redis (localhost)                                            │    │
│  ├─ Tailscale (100.122.164.104)                                 │    │
│  └─ WireGuard wg0 (10.10.0.3/24)                               │    │
└────────────────────────────────────────────────────────────────┘    │
                                                                       │
                        K3s agent (peanut/k3s VM) joins MAD cluster ──┘
```

> Public IPs are stored encrypted in SOPS vault files and don't appear anywhere in plaintext in this repo.

---

## Repository Structure

```
homelab/
├── .github/workflows/
│   └── validate.yml            # Validate + plan on every PR
├── .sops.yaml                  # SOPS rules (public keys only)
├── .gitignore
│
├── infrastructure/tofu/
│   ├── live/
│   │   ├── root.hcl            # Root config: remote state, providers, SOPS
│   │   ├── common.sops.json    # Shared encrypted secrets (B2, SSH key, tokens)
│   │   ├── almond/
│   │   │   ├── region.hcl
│   │   │   ├── secrets.sops.json
│   │   │   ├── lxc/
│   │   │   └── vms/
│   │   ├── peanut/
│   │   │   ├── region.hcl
│   │   │   ├── secrets.sops.json
│   │   │   ├── lxc/
│   │   │   └── vms/
│   │   ├── ovh/
│   │   │   ├── region.hcl
│   │   │   ├── secrets.sops.json
│   │   │   └── vps/
│   │   └── ovh-gra/
│   │       ├── region.hcl
│   │       ├── secrets.sops.json
│   │       └── vps/
│   └── modules/
│       ├── proxmox-lxc/
│       ├── proxmox-vm/
│       └── ovh-vps/
│
├── ansible/
│   ├── inventories/
│   │   ├── almond/
│   │   ├── peanut/
│   │   ├── ovh/
│   │   └── ovh-gra/
│   ├── group_vars/
│   │   ├── ovh_k3s/
│   │   │   ├── vars.yml
│   │   │   └── vault.sops.yml  # Encrypted: IPs, K3s token, OVH API creds
│   │   └── ovh_gra/
│   │       ├── vars.yml
│   │       └── vault.sops.yml  # Encrypted: IP, WireGuard key
│   └── playbooks/
│
├── scripts/
│   ├── age-keygen.sh
│   ├── sops-encrypt.sh
│   └── validate.sh             # Check for secret leaks before committing
│
└── docs/
    ├── ovh-api-token-setup.md
    ├── proxmox-token-security.md
    └── roadmap.md
```

---

## Secret Management

Everything sensitive is encrypted with [SOPS](https://github.com/getsops/sops) + [Age](https://github.com/FiloSottile/age) before being committed. No plaintext secrets anywhere in the repo — not IPs, not tokens, not keys.

```
plaintext secret  →  sops --encrypt (age public key)  →  secrets.sops.json  (committed)
                                                               │
                      Terragrunt / Ansible ←  sops --decrypt (age private key, local only)
```

- **Terragrunt** uses `sops_decrypt_file()` — secrets are never written to disk
- **Ansible** uses the `community.sops` vars plugin — `vault.sops.yml` files are decrypted in memory
- **CI** receives the age private key as a GitHub Actions secret (`SOPS_AGE_KEY`)

### Adapting This for Your Own Setup

```bash
# 1. Generate an age keypair
./scripts/age-keygen.sh
# Follow the output — it tells you what to add to .sops.yaml and where to store the key

# 2. Update .sops.yaml with your public key (replace the existing one)

# 3. Create your secrets from the examples
cp infrastructure/tofu/live/almond/secrets.sops.json.example \
   infrastructure/tofu/live/almond/secrets.json
# Fill in real values, then encrypt:
./scripts/sops-encrypt.sh infrastructure/tofu/live/almond/secrets.json

# 4. Edit encrypted secrets any time with:
sops infrastructure/tofu/live/almond/secrets.sops.json
```

---

## Usage

### Plan / Apply

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

# Plan a specific stack
cd infrastructure/tofu/live/almond/lxc
terragrunt plan

# Apply all stacks on a node
cd infrastructure/tofu/live/almond
terragrunt run-all apply

# Plan everything
cd infrastructure/tofu/live
terragrunt run-all plan
```

### Ansible

```bash
# Check connectivity
ansible -i ansible/inventories/almond all -m ping

# Dry run
ansible-playbook -i ansible/inventories/almond ansible/playbooks/site.yml --check --diff
```

### Validate Before Committing

```bash
./scripts/validate.sh
```

---

## CI/CD

Every PR runs:

1. `scripts/validate.sh` — scans for secret leaks
2. `terragrunt validate` — syntax checks all modules (uses `SOPS_AGE_KEY` Actions secret)
3. `ansible-lint` — lints all playbooks

To set up CI on a fork, add `SOPS_AGE_KEY` to GitHub Actions secrets (Settings → Secrets → Actions). The value is the full contents of your `~/.config/sops/age/keys.txt`.

---

## Prerequisites

| Tool | Version |
|---|---|
| OpenTofu | >= 1.7 |
| Terragrunt | >= 0.58 |
| Ansible | >= 2.16 |
| SOPS | >= 3.8 |
| age | >= 1.1 |
| community.sops collection | >= 0.19 |

---

## License

MIT
