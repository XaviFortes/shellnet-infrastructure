# Homelab IaC — Current State & Roadmap

## Honest Assessment: Where Things Stand Right Now

The repo has a solid **skeleton** but nothing is operational yet as IaC.
The infrastructure *exists and runs*, but it was built manually — the code
describes it but has never been applied against it. Here is what works,
what is broken, and in what order to fix things.

---

## What Actually Works Today

| Item | Status | Notes |
|---|---|---|
| SOPS + Age encryption | ✅ Working | `almond/secrets.sops.json` encrypts/decrypts correctly |
| `.gitignore` | ✅ Working | Tested, no secrets leak |
| `scripts/validate.sh` | ✅ Working | Catches plain tfvars, unencrypted files, public IPs |
| `scripts/sops-encrypt.sh` | ✅ Working | Fixed `--output` flag issue |
| OVH API read access | ✅ Working | Token `<OVH_APP_KEY>...` with `path: *` |
| Proxmox API connectivity | ✅ Working | Both nodes reachable |
| SSH to all servers | ✅ Working | All 4 OVH + Proxmox |
| Directory structure | ✅ Done | All nodes modelled correctly |

## What Is Broken or Missing

| Item | Status | Blocker |
|---|---|---|
| OpenTofu not installed | ❌ | Nothing can be planned or applied |
| Terragrunt not installed | ❌ | Nothing can be planned or applied |
| Ansible not installed | ❌ | No configuration management |
| `opentofu@pve` token reads empty VMs/LXCs | ❌ | `privsep=1` + role has no path-level grants |
| Module bodies are empty stubs | ❌ | `main.tf` files exist but have no real resources |
| No remote state backend configured yet | ❌ | Backblaze B2 creds in secrets but bucket not tested |
| Secrets for peanut/ovh/ovh-gra not created | ❌ | Only almond has a real `secrets.sops.json` |
| Ansible vault files are placeholders | ❌ | OVH IPs not yet encrypted into vault files |
| Certbot cert expired on vps-f24bf8b4 | ❌ | `kubeadm-deb.almond.inovexservices.com` expired 2025-10-10 |

---

## Ordered Roadmap

### Phase 1 — Local Tooling (1 hour)
Get the tools installed so you can actually run things.

```bash
# Install OpenTofu
brew install opentofu

# Install Terragrunt
brew install terragrunt

# Install Ansible + community.sops
brew install python3
pip3 install ansible ansible-lint
ansible-galaxy collection install community.sops

# Verify
tofu version        # >= 1.7
terragrunt --version # >= 0.58
ansible --version
```

---

### Phase 2 — Fix the Proxmox Token (15 min)

The `opentofu@pve!homelab-iac` token has `privsep=1` (privilege separation)
which means the **token** needs its own explicit ACL entry, not just the user.

In Proxmox UI → Datacenter → Permissions → Add → **API Token Permission**:

| Field | Value |
|---|---|
| Path | `/` |
| API Token | `opentofu@pve!homelab-iac` |
| Role | `TofuProvisioner` |
| Propagate | ✓ |

After this, `tofu plan` will actually be able to read existing VMs and LXCs.

**Test it:**
```bash
curl -sk \
  -H "Authorization: PVEAPIToken=opentofu@pve!homelab-iac=<TOKEN_FROM_SOPS>" \
  "https://10.0.1.1:8006/api2/json/nodes/almond/lxc" | python3 -m json.tool
```
Should return the actual LXC list instead of `[]`.

---

### Phase 3 — Fill Real Secrets (30 min)

Create and encrypt `secrets.sops.json` for each remaining node.

```bash
# peanut (same Proxmox cluster, same token)
cp infrastructure/tofu/live/almond/secrets.sops.json.example \
   infrastructure/tofu/live/peanut/secrets.json
# edit peanut/secrets.json — same values as almond except state key differs
./scripts/sops-encrypt.sh infrastructure/tofu/live/peanut/secrets.json

# OVH MAD nodes
cp infrastructure/tofu/live/ovh/secrets.sops.json.example \
   infrastructure/tofu/live/ovh/secrets.json
# edit: add OVH API keys, k3s token (get from: ssh debian@<vps> sudo cat /var/lib/rancher/k3s/server/token)
./scripts/sops-encrypt.sh infrastructure/tofu/live/ovh/secrets.json

# OVH GRA node
cp infrastructure/tofu/live/ovh-gra/secrets.sops.json.example \
   infrastructure/tofu/live/ovh-gra/secrets.json
./scripts/sops-encrypt.sh infrastructure/tofu/live/ovh-gra/secrets.json
```

**Also encrypt the Ansible vault with OVH IPs:**
```bash
sops ansible/group_vars/ovh_k3s/vault.sops.yml
# Add: vault_ovh_ip_vps_6b58f204, vault_ovh_ip_vps_04483f6e, vault_ovh_ip_vps_d147fb4d

sops ansible/group_vars/ovh_gra/vault.sops.yml
# Add: vault_ovh_ip_vps_f24bf8b4
```

---

### Phase 4 — Complete the OpenTofu Modules (2-4 hours)

The module `main.tf` files are stubs. They need real resource definitions.
Priority order (lowest risk first — import existing, don't create new):

#### 4a. `proxmox-lxc` module — import existing containers

The `bpg/proxmox` provider supports importing existing LXCs.

```bash
cd infrastructure/tofu/live/almond/lxc
terragrunt init
# Import each existing container (don't apply yet — just import state)
terragrunt import 'proxmox_virtual_environment_container.lxc["minecraft"]' almond/2005
terragrunt import 'proxmox_virtual_environment_container.lxc["postgres"]' almond/2003
# ... etc for each container
```

Then run `terragrunt plan` — it will show drift between real config and your HCL.
Fix the HCL until plan shows no changes. Only then are you safe to `apply`.

#### 4b. `proxmox-vm` module — same import pattern

```bash
cd infrastructure/tofu/live/almond/vms
terragrunt init
terragrunt import 'proxmox_virtual_environment_vm.vm["docker"]' almond/2103
# ... etc
terragrunt plan  # fix drift before ever running apply
```

#### 4c. `ovh-vps` module — import existing VPS

```bash
cd infrastructure/tofu/live/ovh/vps
terragrunt init
terragrunt import 'ovh_vps.vps["vps-6b58f204"]' vps-6b58f204.vps.ovh.net
terragrunt import 'ovh_vps.vps["vps-04483f6e"]' vps-04483f6e.vps.ovh.net
terragrunt import 'ovh_vps.vps["vps-d147fb4d"]' vps-d147fb4d.vps.ovh.net
terragrunt plan
```

---

### Phase 5 — Validate the CI Pipeline (1 hour)

Push to GitHub and confirm the Actions pipeline passes.

```bash
git init
git remote add origin git@github.com:<you>/homelab.git
git add .
git commit -m "feat: initial homelab IaC skeleton"
git push -u origin main
```

The `validate.yml` workflow will:
1. Run `scripts/validate.sh` — check for secrets in plaintext
2. Run `terragrunt validate` — syntax check all modules (needs `SOPS_AGE_KEY` secret set in GitHub)
3. Run `ansible-lint` — check playbook syntax

**Set the GitHub secret:**
GitHub repo → Settings → Secrets → Actions → New secret:
- Name: `SOPS_AGE_KEY`
- Value: the full contents of `~/.config/sops/age/keys.txt`

---

### Phase 6 — Ansible Roles (ongoing)

The playbooks exist but the role bodies are empty. Fill them in order of
value, starting with what you'll actually use:

1. **`common`** — SSH hardening, fail2ban, unattended-upgrades, timezone, NTP
2. **`proxmox-baseline`** — PVE updates, storage config, VLAN setup
3. **`k3s-node`** — K3s install/upgrade via the official install script
4. **`ovh-haproxy`** (new role needed) — manage HAProxy config on vps-f24bf8b4,
   renew the expired cert

**Test Ansible without making changes:**
```bash
# Dry run against OVH GRA node (least risky — it's a bastion, not K3s)
ansible-playbook -i ansible/inventories/ovh-gra \
  ansible/playbooks/site.yml \
  --check --diff \
  -l vps-f24bf8b4

# Check connectivity to all hosts
ansible -i ansible/inventories/ovh all -m ping
```

---

### Phase 7 — Immediate Fixes (do these now, independent of IaC)

These are not IaC tasks — they are live operational issues found during audit:

1. **Renew the expired cert on vps-f24bf8b4:**
   ```bash
   ssh debian@<gra-ip>
   sudo certbot renew --force-renewal
   # If HAProxy ACME backend is configured, it should auto-renew
   ```

2. **The `root@pam!opencode-api` token still has full admin access.**
   Revoke it once you've confirmed `opentofu@pve!homelab-iac` works:
   Proxmox UI → Datacenter → Permissions → API Tokens → remove `root@pam!opencode-api`

3. **No swap on OVH nodes.** With 8GB RAM and workloads like Longhorn + K3s,
   OOM kills are a real risk. Consider adding a swapfile:
   ```bash
   # On each OVH MAD node
   sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile
   sudo mkswap /swapfile && sudo swapon /swapfile
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   ```

---

## How to Test That You're Doing Things Correctly

### The golden rule: `plan` before `apply`, `import` before both.

Since all infrastructure already exists, the workflow is always:

```
import existing resource → plan (fix drift) → plan shows 0 changes → commit
```

Never run `apply` on existing resources until `plan` shows zero changes.

### Terragrunt validation (no credentials needed):

```bash
# Syntax check all modules without connecting to anything
cd infrastructure/tofu/live
terragrunt run-all validate --terragrunt-non-interactive
```

### Format check:

```bash
# Check HCL formatting (run before every commit)
terragrunt hclfmt --check --diff
tofu fmt -check -recursive infrastructure/tofu/modules/
```

### Secret leak check:

```bash
# Run before every commit — the most important check
./scripts/validate.sh
```

### Ansible dry run (safe, no changes):

```bash
ansible-playbook -i ansible/inventories/ovh-gra \
  ansible/playbooks/site.yml --check --diff
```

### Ansible syntax check (no connection needed):

```bash
ansible-playbook ansible/playbooks/site.yml --syntax-check
```

---

## Priority Summary

| Priority | Task | Time |
|---|---|---|
| 🔴 Now | Install tofu + terragrunt + ansible | 1h |
| 🔴 Now | Fix Proxmox token ACL (privsep issue) | 15min |
| 🔴 Now | Renew expired cert on vps-f24bf8b4 | 10min |
| 🟠 Soon | Encrypt remaining secrets files | 30min |
| 🟠 Soon | Push repo to GitHub, set SOPS_AGE_KEY secret | 15min |
| 🟠 Soon | Complete proxmox-lxc module, import containers | 2h |
| 🟡 Next | Complete proxmox-vm module, import VMs | 2h |
| 🟡 Next | Import OVH VPS into state | 1h |
| 🟡 Next | Write `common` Ansible role | 2h |
| 🟢 Later | Write remaining Ansible roles | ongoing |
| 🟢 Later | Add ArgoCD app-of-apps pattern for K3s workloads | ongoing |
