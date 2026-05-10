# terragrunt.hcl — ovh-gra / vps
# Manages the Gravelines edge/bastion VPS (vps-f24bf8b4).
#
# Role: HAProxy edge node — the single public entrypoint that fans out to:
#   - nginxproxymanager (peanut LXC, 10.0.1.102) for HTTP/HTTPS
#   - kubeadm API server (10.2.1.2:6443) for kubectl remote access
#   - Minecraft server (10.2.0.5:25565 and 10.2.1.7:25565)
#   - TrueNAS (via Tailscale 100.105.115.101) on port 51820
#   - external domain backends (external IPs — see vault.sops.yml)
#
# Also running:
#   - Redis (localhost only, for HAProxy/app use)
#   - Tailscale (100.122.164.104) — mesh connectivity to homelab
#   - WireGuard wg0 (10.10.0.3/24)
#   - Zabbix agent (reporting to 100.70.14.45 via Tailscale)
#   - Certbot + Let's Encrypt via HAProxy ACME backend
#
# Import command (one-time):
#   terragrunt import 'ovh_vps.vps["vps-f24bf8b4"]' vps-f24bf8b4.vps.ovh.net
include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  node_vars       = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  _common_secrets = jsondecode(sops_decrypt_file("${get_parent_terragrunt_dir()}/common.sops.json"))
  _node_secrets   = jsondecode(sops_decrypt_file(find_in_parent_folders("secrets.sops.json")))
  secrets         = merge(local._common_secrets, local._node_secrets)
}

terraform {
  source = "../../../modules//ovh-vps"
}

inputs = {
  ovh_endpoint   = local.node_vars.locals.ovh_endpoint
  ssh_public_key = local.secrets.ssh_public_key
  ssh_key_name   = "homelab-key"

  vps_instances = [
    {
      # vps-f24bf8b4: AMD EPYC Milan 2vCPU / 2GB RAM / 40GB SSD — Gravelines GRA8
      # Edge/bastion: HAProxy, Redis, Tailscale, Zabbix, WireGuard
      # Created: 2023-08-28 (oldest, predates MAD cluster)
      name        = "vps-f24bf8b4"
      plan        = "vps-le-2-2-40"
      os_template = local.node_vars.locals.os
      region      = local.node_vars.locals.zone
    },
  ]
}
