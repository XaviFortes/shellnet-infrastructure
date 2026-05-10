# Roadmap & Notes

Current state of the IaC, what's working, what's still pending, and notes for future work.

---

## What's Working

| Component | Status | Notes |
|---|---|---|
| SOPS + Age encryption | ✅ | All secrets encrypted, decrypt/re-encrypt tested |
| `.gitignore` | ✅ | Validated — no secrets leak |
| `scripts/validate.sh` | ✅ | Catches plain tfvars, unencrypted files, raw IPs |
| `scripts/sops-encrypt.sh` | ✅ | Working |
| Proxmox API (both nodes) | ✅ | `opentofu@pve!homelab-iac` token confirmed working |
| OVH API | ✅ | GET access to all 4 VPS confirmed |
| almond/lxc | ✅ | 6 LXCs imported, plan = no changes |
| almond/vms | ✅ | 6 VMs imported, plan = no changes |
| peanut/lxc | ✅ | 4 LXCs imported, plan = no changes |
| peanut/vms | ✅ | 4 VMs imported, plan = no changes |
| ovh/vps (MAD) | ✅ | 3 VPS imported, plan = no changes |
| ovh-gra/vps | ✅ | 1 VPS imported, plan = no changes |
| Remote state (B2) | ✅ | All 6 stacks using Backblaze B2 backend |

---

## Pending / Known Issues

| Item | Notes |
|---|---|
| Cert expired on vps-f24bf8b4 | One domain cert expired 2025-10-10. Needs Cloudflare API token (Zone:DNS:Edit) to renew via certbot DNS challenge. |
| Ansible roles are empty | Role directories exist but role bodies haven't been written yet. |
| No swap on MAD VPS | 8GB RAM with Longhorn + K3s is tight. Worth adding a 4GB swapfile on each. |
| `pve-node-01` / `pve-node-02` refs | Old naming is gone from IaC but may still appear in some Ansible playbook comments. |

---

## Import Pattern (for reference)

All infrastructure pre-existed and was imported rather than created fresh. The pattern used throughout:

```
terragrunt init
terragrunt import '<resource>["<name>"]' <provider-id>
terragrunt plan   # fix ignore_changes until plan = no changes
# commit — never apply on existing resources until plan is clean
```

Notable gotchas encountered:

- **OVH VPS import ID must be FQDN**: `vps-XXXX.vps.ovh.net`, not the short name
- **`ovh_vps` resource has no IP attribute**: use a `data "ovh_vps"` source to read IPs separately
- **Proxmox feature flags (keyctl, fuse) require `root@pam`**: the IaC token can't change them — add to `ignore_changes`
- **LXC descriptions set by Helper Scripts**: add `description` to `ignore_changes`
- **VM `serial_device` on cloud-image VMs**: not managed by this config, ignore it
- **B2 backend returns 501 on lock**: use `use_lockfile = false` in the root config

---

## Next Steps

### Short term

- Renew cert on vps-f24bf8b4 (need Cloudflare token)
- Write `common` Ansible role: SSH hardening, fail2ban, unattended-upgrades, NTP
- Write `proxmox-baseline` role: PVE updates, storage, VLAN config
- Write `k3s-node` role: K3s install/upgrade via official install script
- Write `ovh-haproxy` role: manage HAProxy config on vps-f24bf8b4

### Longer term

- ArgoCD app-of-apps pattern for K3s workloads (currently applied manually)
- Migrate kubeadm cluster to K3s (simplifies the two-cluster setup)
- Add monitoring: Prometheus + Grafana on peanut or a dedicated LXC
- Automate cert renewal via certbot + DNS challenge in Ansible

---

## OVH API Notes

The MAD1 LocalZone VPS (`vps-2025-model1.LZ`) don't expose `/vps/{name}/distribution` or `/vps/{name}/disks` — these return 404. It's a known LocalZone limitation. OS and disk info has to come from SSH or the OVH console.

The current OVH API token is read-only (GET only). For full lifecycle management a token with POST/PUT/DELETE rules would be needed — not necessary right now since VPS were imported.

## Proxmox Token Notes

The `opentofu@pve!homelab-iac` token uses privilege separation (`privsep=1`) — the token itself needs explicit ACL entries, not just the `opentofu@pve` user. See `docs/proxmox-token-security.md` for the full setup.

Feature flags (keyctl, fuse, nesting) on LXCs require `root@pam` to modify — the IaC token will always 403 on those. They're added to `ignore_changes` in the proxmox-lxc module.
