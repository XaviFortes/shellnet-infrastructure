# API Token Security — Proxmox Privilege Reduction

## Current State (Action Required)

The `root@pam!opencode-api` token currently has **full administrator privileges** because it is owned by `root@pam`. This is equivalent to giving a CI/CD system root access to your entire Proxmox cluster.

**This is a security risk for a public repo workflow.** If the token is ever leaked (e.g., via a CI log, a decryption failure, or accidental commit), an attacker has full control of both nodes.

---

## Recommended: Create a Dedicated Least-Privilege User

### Step 1 — Create a dedicated PVE user

In Proxmox UI → Datacenter → Permissions → Users → Add:

| Field | Value |
|---|---|
| User name | `opentofu` |
| Realm | `pve` (not `pam`) |
| Comment | IaC automation user |

### Step 2 — Create a Role with only what OpenTofu needs

Datacenter → Permissions → Roles → Create:

Role name: `TofuProvisioner`

Required privileges:

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
| `VM.Audit` | Read VM status (for plan) |
| `Datastore.AllocateSpace` | Write disk images to storage |
| `Datastore.AllocateTemplate` | Upload/use templates |
| `Datastore.Audit` | Read storage info |
| `Sys.Audit` | Read node status (for plan) |

**Intentionally excluded:** `Sys.PowerMgmt`, `Sys.Modify`, `Sys.Console`, `Permissions.Modify`, `User.Modify`, `SDN.Allocate`, `Pool.Allocate`

### Step 3 — Assign the role

Datacenter → Permissions → Add → User Permission:

| Field | Value |
|---|---|
| Path | `/` |
| User | `opentofu@pve` |
| Role | `TofuProvisioner` |
| Propagate | ✓ |

### Step 4 — Create the API token

Datacenter → Permissions → API Tokens → Add:

| Field | Value |
|---|---|
| User | `opentofu@pve` |
| Token ID | `homelab-iac` |
| Privilege Separation | ✓ (enabled — token cannot exceed user's own privileges) |

Update your `secrets.sops.json`:
```json
"proxmox_api_token": "opentofu@pve!homelab-iac=<new-token-value>"
```

### Step 5 — Revoke the old token

Datacenter → Permissions → API Tokens → select `root@pam!opencode-api` → Remove.

---

## Why `pve` realm instead of `pam`?

- `pam` = Linux PAM — the user exists at the OS level. A compromised token could potentially be leveraged for SSH.
- `pve` = Proxmox-only — the user exists only within the Proxmox permission system. No OS-level access.

---

## Token Storage

The token value lives **only** in:
1. `infrastructure/tofu/live/*/secrets.sops.json` — encrypted with Age, safe to commit
2. GitHub Actions secret `SOPS_AGE_KEY` — the age private key that can decrypt it
3. Your local `~/.config/sops/age/keys.txt` — never committed

It is **never** in:
- `.tfvars` files
- Environment variables in CI logs
- Plaintext anywhere in this repo
