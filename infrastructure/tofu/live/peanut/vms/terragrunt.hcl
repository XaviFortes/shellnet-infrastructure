# terragrunt.hcl — peanut / vms
# Manages Linux QEMU VMs on the peanut node.
#
# NOT managed here (appliances — no cloud-init, special config):
#   100  opnsense   - router/firewall appliance
#   104  TrueNAS    - NAS appliance (passthrough disks)
#   106  haos15.2   - Home Assistant OS (UEFI/OVMF, special disk)
#
# Managed VMs:
#   101  k3s         (running)  - K3s node (homelab cluster)
#   105  hestiacp    (stopped)  - web hosting control panel
#   107  mailcow     (stopped)  - mail server
#   108  kubeadm-h2  (stopped)  - kubeadm HA node 2
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
  source = "../../../modules//proxmox-vm"
}

inputs = {
  node_name       = local.node_vars.locals.proxmox_node
  storage_pool    = local.node_vars.locals.storage_pool
  network_bridge  = local.node_vars.locals.network_bridge
  ssh_public_keys = local.secrets.ssh_public_key

  virtual_machines = [
    {
      name          = "k3s"
      vmid          = 101
      cores         = 6
      memory        = 8192
      balloon       = 0
      disk_size     = "100G"
      cpu_type      = "host"
      tags          = ["k3s"]
      start_on_boot = true
      firewall      = false
    },
    {
      name          = "hestiacp"
      vmid          = 105
      cores         = 6
      memory        = 8192
      balloon       = 2048
      disk_size     = "200G"
      cpu_type      = "x86-64-v2-AES"
      tags          = ["web"]
      start_on_boot = false
      firewall      = true
    },
    {
      name          = "mailcow"
      vmid          = 107
      cores         = 4
      memory        = 6144
      balloon       = 0
      disk_size     = "50G"
      cpu_type      = "host"
      tags          = ["mail"]
      start_on_boot = false
      firewall      = true
    },
    {
      name          = "kubeadm-h2"
      vmid          = 108
      cores         = 6
      memory        = 6144
      balloon       = 0
      disk_size     = "50G"
      cpu_type      = "x86-64-v2-AES"
      tags          = ["kubernetes"]
      start_on_boot = false
      firewall      = true
    },
  ]
}
