# region.hcl — almond
# Non-sensitive, node-specific values. Safe to commit.
# Node: AMD Ryzen 7 5800X | 64GB RAM | Proxmox 8.4
locals {
  region           = "homelab"
  proxmox_node     = "almond"
  proxmox_endpoint = "https://10.0.2.1:8006"
  network_bridge   = "vmbr0"
  storage_pool     = "local-lvm"
  storage_iso      = "local"
}
