# OVH API Token Setup

## Token History

| App Key | Status | Issue |
|---|---|---|
| `47c4976b8601f50f` | ❌ Broken | Created with `path: ""` — only grants access to `GET /` |
| `<OVH_APP_KEY_FROM_SOPS>` | ✅ Working | `path: "*"` — full GET access confirmed |

The working token (`<OVH_APP_KEY_FROM_SOPS>`) has been verified against the API:
- `GET /vps` → returns all 4 VPS
- `GET /vps/{name}` → returns plan, zone, state, IPs
- `GET /me` → returns account info
- `GET /ip` → returns all IP blocks on account

**This token is read-only (GET only).** For full lifecycle management (create/delete/modify VPS), a new token with POST/PUT/DELETE rules would be needed.

## Current Infrastructure Discovered via API (2026-05-10)

### VPS Inventory

| Hostname | Region | Plan | vCPU | RAM | Disk | IPv4 (→ vault) | Created |
|---|---|---|---|---|---|---|---|
| vps-6b58f204 | MAD1 LocalZone | vps-2025-model1.LZ | 4 | 8GB | 75GB | vault_ovh_ip_vps_6b58f204 | 2025-11-15 |
| vps-04483f6e | MAD1 LocalZone | vps-2025-model1.LZ | 4 | 8GB | 75GB | vault_ovh_ip_vps_04483f6e | 2025-11-15 |
| vps-d147fb4d | MAD1 LocalZone | vps-2025-model1.LZ | 4 | 8GB | 75GB | vault_ovh_ip_vps_d147fb4d | 2025-11-15 |
| vps-f24bf8b4 | GRA8 (eu-west-gra) | vps-le-2-2-40 (2019v1) | 2 | 2GB | 40GB | vault_ovh_ip_vps_f24bf8b4 | 2023-08-28 |

All 4 renew monthly, next expiry: **2026-06-01**. Auto-renewal is enabled.

### IPv6 Addresses (non-sensitive — not routed to your domain)

| Hostname | IPv6 |
|---|---|
| vps-6b58f204 | 2001:41d0:ab00::4:0:ee |
| vps-04483f6e | 2001:41d0:ab00::4:0:ef |
| vps-d147fb4d | 2001:41d0:ab00::4:0:f0 |
| vps-f24bf8b4 | 2001:41d0:304:200::610d |

## Creating a New Token (if needed)

Go to [https://eu.api.ovh.com/createToken/](https://eu.api.ovh.com/createToken/) and set:

| Method | Path | Why |
|---|---|---|
| GET | `/vps` | List VPS |
| GET | `/vps/*` | Read VPS details (IPs, plan, state) |
| GET | `/me` | Account info |
| GET | `/ip` | List all IPs |
| GET | `/ip/*` | IP details and routing |

For full Terraform lifecycle (future):

| Method | Path |
|---|---|
| POST | `/order/cartServiceOption/vps/*` |
| PUT | `/vps/*` |
| DELETE | `/vps/*` |

## Note on Madrid LocalZone API Behaviour

The MAD1 LocalZone VPS (`vps-2025-model1.LZ`) do not expose `/vps/{name}/distribution` or `/vps/{name}/disks` endpoints — these return 404. This is a known OVH LocalZone API limitation. OS and disk info must be obtained via SSH or the OVH console.
