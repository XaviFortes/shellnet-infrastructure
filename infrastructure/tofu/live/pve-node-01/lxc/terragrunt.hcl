# terragrunt.hcl — pve-node-01 / lxc
# Instantiates the proxmox-lxc module for this node.
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules//proxmox-lxc"
}

inputs = {
  lxc_containers = [
    {
      hostname  = "dns-01"
      vmid      = 101
      cores     = 1
      memory    = 512
      disk_size = "8G"
      ip        = "dhcp"
      template  = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
      tags      = ["dns", "infrastructure"]
    },
    {
      hostname  = "monitoring-01"
      vmid      = 102
      cores     = 2
      memory    = 2048
      disk_size = "20G"
      ip        = "dhcp"
      template  = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
      tags      = ["monitoring", "infrastructure"]
    },
  ]
}
