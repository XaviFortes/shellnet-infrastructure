# region.hcl — ovh-gra
# Non-sensitive values for the Gravelines (GRA8) VPS. Safe to commit.
#
# Discovered facts (2026-05-10):
#   - Location: Gravelines GRA8 (eu-west-gra region) — NOT a LocalZone
#   - Plan: vps-le-2-2-40 (2019v1) — 2 vCPU, 2GB RAM, 40GB SSD
#   - CPU: AMD EPYC Milan
#   - OS: Debian 12 (bookworm), kernel standard
#   - Created: 2023-08-28 (oldest VPS, predates MAD cluster)
#   - Role: edge/bastion node — HAProxy L4/L7, Redis, Tailscale, Zabbix agent
#   - No K3s, no Docker
#   - Tailscale: active (100.122.164.104)
#   - WireGuard: wg0 on 10.10.0.3/24
#   - Certbot: Let's Encrypt via haproxy acme backend
locals {
  region       = "ovh-eu"
  ovh_endpoint = "ovh-eu"
  zone         = "GRA8"
  provider     = "ovh"
  node_name    = "vps-f24bf8b4"
  ssh_user     = "debian"
  os           = "debian12-64"
  vps_vcpus    = 2
  vps_ram_mb   = 2048
  vps_disk_gb  = 40
}
