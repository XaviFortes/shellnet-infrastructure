# region.hcl — pve-node-02
# Non-sensitive, node-specific values. Safe to commit.
locals {
  region           = "homelab-eu"
  proxmox_endpoint = "https://pve-02.lan:8006"   # replace with your actual hostname
  node_name        = "pve-node-02"
}
