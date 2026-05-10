# terragrunt.hcl — peanut / lxc
# Manages LXC containers on the peanut node.
# Current containers: nginxproxymanager, adguard, homarr, postgres-replica
include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  node_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  _common_secrets = jsondecode(sops_decrypt_file("${get_parent_terragrunt_dir()}/common.sops.json"))
  _node_secrets   = jsondecode(sops_decrypt_file(find_in_parent_folders("secrets.sops.json")))
  secrets         = merge(local._common_secrets, local._node_secrets)
}

terraform {
  source = "../../../modules//proxmox-lxc"
}

inputs = {
  node_name       = local.node_vars.locals.proxmox_node
  storage_pool    = local.node_vars.locals.storage_pool
  network_bridge  = local.node_vars.locals.network_bridge
  ssh_public_keys = local.secrets.ssh_public_key

  lxc_containers = [
    {
      hostname      = "nginxproxymanager"
      vmid          = 102
      cores         = 1
      memory        = 1024
      swap          = 512
      disk_size     = "4G"
      ip            = "10.0.1.102/14"
      gateway       = "10.0.0.1"
      os_type       = "debian"
      template      = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
      tags          = ["lxc", "proxy"]
      start_on_boot = true
      features      = { nesting = true }
      firewall      = false
    },
    {
      hostname      = "homarr"
      vmid          = 103
      cores         = 2
      memory        = 1024
      swap          = 512
      disk_size     = "8G"
      ip            = "172.16.4.103/16"
      gateway       = "172.16.0.250"
      os_type       = "debian"
      template      = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
      tags          = ["lxc", "dashboard"]
      start_on_boot = true
      features      = { nesting = true }
      firewall      = false
    },
    {
      hostname      = "adguard"
      vmid          = 109
      cores         = 1
      memory        = 512
      swap          = 512
      disk_size     = "2G"
      ip            = "dhcp"
      os_type       = "debian"
      template      = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
      tags          = ["lxc", "dns"]
      start_on_boot = true
      features      = { nesting = true }
      firewall      = false
    },
    {
      hostname      = "postgres-replica"
      vmid          = 3001
      cores         = 1
      memory        = 512
      swap          = 512
      disk_size     = "6G"
      ip            = "10.3.0.1/14"
      gateway       = "10.0.0.1"
      os_type       = "alpine"
      template      = "local:vztmpl/alpine-3.22-default_20250617_amd64.tar.xz"
      tags          = ["lxc", "databases"]
      start_on_boot = false
      features      = { nesting = true }
      firewall      = true
    },
  ]
}
