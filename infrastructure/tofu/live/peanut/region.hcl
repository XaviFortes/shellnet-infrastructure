# region.hcl — peanut
# Non-sensitive, node-specific values. Safe to commit.
# Node: AMD Ryzen 5 3600 | 32GB RAM | Proxmox 8.4
locals {
  region           = "homelab"
  proxmox_node     = "peanut"
  proxmox_endpoint = "https://10.0.1.1:8006"
  network_bridge   = "vmbr0"
  storage_pool     = "local-lvm"
  storage_iso      = "local"
}
