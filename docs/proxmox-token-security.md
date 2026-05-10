# Proxmox API Token Setup

## The Approach: Dedicated Least-Privilege User

Rather than using a `root@pam` token (which gives full admin access to the whole cluster), I created a dedicated Proxmox-only user with a minimal role. This way if the token ever leaks, the blast radius is limited to what OpenTofu actually needs.

---

## Setup Steps

### 1. Create a PVE user

Datacenter → Permissions → Users → Add:

| Field | Value |
|---|---|
| User name | `opentofu` |
| Realm | `pve` (not `pam` — Proxmox-only, no OS-level access) |
| Comment | IaC automation |

### 2. Create a role with only what's needed

Datacenter → Permissions → Roles → Create:

Role name: `TofuProvisioner`

| Privilege | Why |
|---|---|
| `VM.Allocate` | Create/delete VMs and LXCs |
| `VM.Clone` | Clone from templates |
| `VM.Config.CPU` | Set CPU cores |
| `VM.Config.Memory` | Set RAM |
| `VM.Config.Disk` | Attach disks |
| `VM.Config.Network` | Configure network interfaces |
| `VM.Config.Options` | Set tags, boot order, description |
| `VM.Config.Cloudinit` | Inject cloud-init / SSH keys |
| `VM.PowerMgmt` | Start/stop/reboot |
| `VM.Audit` | Read VM status |
| `Datastore.AllocateSpace` | Write disk images |
| `Datastore.AllocateTemplate` | Upload/use templates |
| `Datastore.Audit` | Read storage info |
| `Sys.Audit` | Read node status |

Intentionally excluded: `Sys.PowerMgmt`, `Sys.Modify`, `Sys.Console`, `Permissions.Modify`, `User.Modify`, `SDN.Allocate`, `Pool.Allocate`

### 3. Assign the role

Datacenter → Permissions → Add → User Permission:

| Field | Value |
|---|---|
| Path | `/` |
| User | `opentofu@pve` |
| Role | `TofuProvisioner` |
| Propagate | ✓ |

### 4. Create the API token

Datacenter → Permissions → API Tokens → Add:

| Field | Value |
|---|---|
| User | `opentofu@pve` |
| Token ID | `homelab-iac` |
| Privilege Separation | ✓ |

**Note on privilege separation:** with `privsep=1` enabled, the token itself needs its own ACL entry — it doesn't inherit from the user automatically. Add an API Token Permission at `/` with role `TofuProvisioner` pointing to `opentofu@pve!homelab-iac`.

The token value goes into `secrets.sops.json` as:
```json
"proxmox_api_token": "opentofu@pve!homelab-iac=<token-value>"
```

---

## Why `pve` Realm, Not `pam`?

- `pam` = Linux PAM user. Exists at the OS level. A leaked token could potentially be leveraged for SSH access.
- `pve` = Proxmox-only user. No shell, no OS-level access. Contained within the Proxmox permission system.

---

## What the Token Can't Do

Feature flags on LXCs (keyctl, fuse, nesting) require `root@pam` to modify. The `TofuProvisioner` role will always get a 403 on those. That's fine — they're added to `ignore_changes` in the proxmox-lxc module so Tofu doesn't try.

---

## Token Storage

The token lives only in:
1. `infrastructure/tofu/live/*/secrets.sops.json` — Age-encrypted, safe to commit
2. GitHub Actions secret `SOPS_AGE_KEY` — the age private key that decrypts it at CI time
3. `~/.config/sops/age/keys.txt` locally — never committed

It is never in plaintext anywhere in this repo.
