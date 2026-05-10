# terragrunt.hcl — almond / lxc
# Manages LXC containers on the almond node.
# Current containers: minecraft, wireguard, postgres, ttyd, coder-server, cloudflared
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
  source = "../../../modules//proxmox-lxc"
}

inputs = {
  node_name      = local.node_vars.locals.proxmox_node
  storage_pool   = local.node_vars.locals.storage_pool
  network_bridge = local.node_vars.locals.network_bridge
  ssh_public_keys = local.secrets.ssh_public_key

  lxc_containers = [
    {
      hostname      = "cloudflared"
      vmid          = 2001
      cores         = 1
      memory        = 512
      swap          = 512
      disk_size     = "1G"
      ip            = "10.2.0.1/14"
      gateway       = "10.0.0.1"
      os_type       = "alpine"
      template      = "local:vztmpl/alpine-3.21-default_20241217_amd64.tar.xz"
      tags          = ["lxc", "cloudflared"]
      start_on_boot = true
      features      = { nesting = true }
      firewall      = true
    },
    {
      hostname      = "wireguard"
      vmid          = 2002
      cores         = 1
      memory        = 256
      swap          = 512
      disk_size     = "2G"
      ip            = "10.2.0.2/14"
      gateway       = "10.0.0.1"
      os_type       = "alpine"
      template      = "local:vztmpl/alpine-3.21-default_20241217_amd64.tar.xz"
      tags          = ["lxc", "vpn"]
      start_on_boot = true
      features      = { nesting = true }
      firewall      = true
    },
    {
      hostname      = "postgres"
      vmid          = 2003
      cores         = 2
      memory        = 1024
      swap          = 512
      disk_size     = "6G"
      ip            = "10.2.0.3/14"
      gateway       = "10.0.0.1"
      os_type       = "alpine"
      template      = "local:vztmpl/alpine-3.21-default_20241217_amd64.tar.xz"
      tags          = ["lxc", "databases"]
      start_on_boot = true
      features      = { nesting = true }
      firewall      = true
    },
    {
      hostname      = "coder-server"
      vmid          = 2004
      cores         = 8
      memory        = 16384
      swap          = 4096
      disk_size     = "30G"
      ip            = "10.2.0.4/14"
      gateway       = "10.0.0.1"
      os_type       = "debian"
      template      = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
      tags          = ["lxc", "coding"]
      start_on_boot = true
      features      = { nesting = true }
      firewall      = true
    },
    {
      hostname      = "minecraft"
      vmid          = 2005
      cores         = 6
      memory        = 8192
      swap          = 2048
      disk_size     = "40G"
      ip            = "10.2.0.5/14"
      gateway       = "10.0.0.1"
      os_type       = "debian"
      template      = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
      tags          = ["lxc", "minecraft"]
      start_on_boot = true
      features      = { nesting = true }
      firewall      = true
    },
    {
      hostname      = "ttyd"
      vmid          = 2006
      cores         = 2
      memory        = 1024
      swap          = 1024
      disk_size     = "8G"
      ip            = "10.2.0.6/14"
      gateway       = "10.0.0.1"
      os_type       = "debian"
      template      = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
      tags          = ["lxc"]
      start_on_boot = true
      features      = { nesting = true }
      firewall      = true
    },
  ]
}
