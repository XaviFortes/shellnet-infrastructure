# Actions Runner Controller (ARC) Setup

Ephemeral self-hosted GitHub Actions runners running on your OVH K3s cluster.
Each job gets a fresh pod — no state leaks between runs. Scales to zero when idle.

## How it works

```
GitHub Actions job (runs-on: homelab)
  │
  ▼
ARC scale-set controller  (arc-systems namespace, managed by ArgoCD)
  │  sees job queued via GitHub App webhook
  ▼
Runner pod created        (arc-runners namespace, ephemeral)
  │  registers, runs job, deregisters, pod deleted
  ▼
Job complete
```

The runners register at the **user account level** (`github.com/XaviFortes`), so every
repository in your personal account can use them — no per-repo setup needed.

---

## One-time setup

### 1. Create a GitHub App

Go to: **GitHub → Settings → Developer settings → GitHub Apps → New GitHub App**

| Field | Value |
|---|---|
| GitHub App name | `homelab-arc-runner` (or anything) |
| Homepage URL | `https://github.com/XaviFortes` |
| Webhook | Disable (uncheck "Active") |
| Repository permissions | Actions: Read-only |
| Organization permissions | _(none)_ |
| User permissions | _(none)_ |
| Where can this be installed? | **Only on this account** |

After creation:
- Note the **App ID** (shown at the top of the App settings page)
- Scroll to **Private keys** → Generate a private key → download the `.pem` file

### 2. Install the App on your account

In the App settings page, click **Install App** → select your account → **All repositories**
(or specific repos — but "All" means any new repo automatically works).

After install, check the URL bar:
```
https://github.com/settings/installations/XXXXXXXX
```
The number at the end is your **Installation ID**.

### 3. Store secrets in SOPS vault

```bash
# Edit the encrypted vault (decrypts in $EDITOR, re-encrypts on save)
sops ansible/group_vars/ovh_k3s/vault.sops.yml
```

Add these keys (values from step 1 and 2):

```yaml
vault_arc_github_app_id: "123456"
vault_arc_github_app_installation_id: "78901234"
vault_arc_github_app_private_key: |
  -----BEGIN RSA PRIVATE KEY-----
  MIIEo...
  -----END RSA PRIVATE KEY-----
```

### 4. Deploy the ARC controller and runner scale set via ArgoCD

Apply both ArgoCD Application manifests to your cluster:

```bash
kubectl apply -f kubernetes/arc/controller/argocd-app.yaml
kubectl apply -f kubernetes/arc/runners/argocd-app.yaml
```

ArgoCD will pull and install the Helm charts. The controller comes up first
(sync-wave 0), then the runner scale set (sync-wave 1).

### 5. Provision the GitHub App secret into K3s

```bash
ansible-playbook -i ansible/inventories/ovh/ ansible/playbooks/arc-secret.yml \
  --limit vps-6b58f204
```

This reads the three vault values and creates the `arc-github-app-secret` Kubernetes
Secret in the `arc-runners` namespace. Re-run whenever you rotate the private key.

### 6. Verify

```bash
# Check controller is running
kubectl get pods -n arc-systems

# Check runner scale set is registered
kubectl get runnerscaleset -n arc-runners

# Watch runners spawn when a job is queued
kubectl get pods -n arc-runners -w
```

---

## Using the runners in any workflow

Add `runs-on: homelab` to any job in any repository under your account:

```yaml
jobs:
  build:
    runs-on: homelab   # targets your K3s runner scale set
    steps:
      - uses: actions/checkout@v5
      - run: echo "Running on homelab!"
```

This works in **any** of your repositories without any per-repo runner registration.

### Label used in this repo

The `tofu-apply` job in `.github/workflows/validate.yml` can be switched to
`runs-on: homelab` to enable Proxmox apply (since the runner is on your LAN via
the OVH VPS → WireGuard tunnel). Update the label when ready:

```yaml
tofu-apply:
  runs-on: homelab   # was: ubuntu-latest
```

---

## Scaling

The scale set is configured with:
- `minRunners: 0` — idles at zero cost when no jobs are queued
- `maxRunners: 4` — up to 4 concurrent jobs (tune to your cluster capacity)

Each runner pod requests 500m CPU / 512Mi RAM and limits to 2 CPU / 4Gi RAM.
Your OVH K3s nodes (4 vCPU / 8GB each) can run ~2 runners per node comfortably.

---

## Files

| Path | Purpose |
|---|---|
| `kubernetes/arc/controller/argocd-app.yaml` | Installs ARC scale-set controller via ArgoCD |
| `kubernetes/arc/runners/argocd-app.yaml` | Defines the `homelab` runner scale set |
| `kubernetes/arc/runners/github-app-secret.yaml.example` | Documents expected Secret shape |
| `ansible/roles/arc-secret/` | Ansible role that writes the Secret from vault |
| `ansible/playbooks/arc-secret.yml` | Playbook to run the above role |
