# region.hcl — pve-node-01
# Non-sensitive, node-specific values. Safe to commit.
locals {
  region           = "homelab-eu"     # logical region label, not a real AWS region
  proxmox_endpoint = "https://pve-01.lan:8006"   # replace with your actual hostname
  node_name        = "pve-node-01"
}
