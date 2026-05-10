# terragrunt.hcl — almond / vms
# Manages QEMU VMs on the almond node.
# Templates (vmid 902, 903, 910, 911, 912) are NOT managed here — they are
# created manually and referenced by other modules as clone sources.
#
# Managed VMs:
#   2101 kubeadm-h1   (kubernetes;cluster) - stopped, part of kubeadm HA
#   2102 kubeadm-deb  (kubernetes)         - running kubeadm worker
#   2103 docker       (docker)             - running general docker host
#   2104 game-server  (stopped)
#   2105 mailcow-dev  (stopped)
#   2106 k3s-ha-ovh-es (running)           - k3s HA node (also OVH-connected)
#   2107 game-server-2 (running)
#   2108 kadm-master  (kubernetes)         - running kubeadm control plane
#   2109 kadm-w1      (kubernetes)         - running kubeadm worker
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
  source = "../../../modules//proxmox-vm"
}

inputs = {
  node_name       = local.node_vars.locals.proxmox_node
  storage_pool    = local.node_vars.locals.storage_pool
  network_bridge  = local.node_vars.locals.network_bridge
  ssh_public_keys = local.secrets.ssh_public_key

  virtual_machines = [
    {
      name          = "kubeadm-deb"
      vmid          = 2102
      cores         = 6
      memory        = 8192
      balloon       = 4096
      disk_size     = "50G"
      cpu_type      = "host"
      tags          = ["kubernetes"]
      start_on_boot = true
      firewall      = true
    },
    {
      name          = "docker"
      vmid          = 2103
      cores         = 6
      memory        = 6144
      balloon       = 0
      disk_size     = "40G"
      cpu_type      = "x86-64-v2-AES"
      tags          = ["docker"]
      start_on_boot = true
      firewall      = false
    },
    {
      name          = "k3s-ha-ovh-es"
      vmid          = 2106
      cores         = 4
      memory        = 16384
      balloon       = 0
      disk_size     = "32G"
      cpu_type      = "host"
      tags          = ["k3s"]
      start_on_boot = true
      firewall      = false
    },
    {
      name          = "game-server-2"
      vmid          = 2107
      cores         = 10
      memory        = 24576
      balloon       = 0
      disk_size     = "150G"
      cpu_type      = "host"
      tags          = ["gaming"]
      start_on_boot = false
      firewall      = false
    },
    {
      name          = "kadm-master"
      vmid          = 2108
      cores         = 4
      memory        = 4096
      balloon       = 0
      disk_size     = "32G"
      cpu_type      = "host"
      tags          = ["kubernetes"]
      start_on_boot = true
      firewall      = true
    },
    {
      name          = "kadm-w1"
      vmid          = 2109
      cores         = 4
      memory        = 4096
      balloon       = 0
      disk_size     = "32G"
      cpu_type      = "x86-64-v2-AES"
      tags          = ["kubernetes"]
      start_on_boot = true
      firewall      = true
    },
  ]
}
