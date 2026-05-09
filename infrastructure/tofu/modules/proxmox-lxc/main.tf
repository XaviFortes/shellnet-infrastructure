# infrastructure/tofu/modules/proxmox-lxc/main.tf

resource "proxmox_virtual_environment_container" "lxc" {
  for_each = { for c in var.lxc_containers : c.hostname => c }

  node_name = var.node_name
  vm_id     = each.value.vmid
  tags      = each.value.tags

  description = "Managed by OpenTofu + Terragrunt"

  initialization {
    hostname = each.value.hostname

    ip_config {
      ipv4 {
        address = each.value.ip == "dhcp" ? "dhcp" : "${each.value.ip}/24"
      }
    }

    user_account {
      # Password is not used — SSH key auth only.
      # Still required by the provider; value comes from SOPS-injected input.
      keys = [var.ssh_public_keys]
    }
  }

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.storage_pool
    size         = each.value.disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  operating_system {
    template_file_id = each.value.template
    type             = "debian"
  }

  start_on_boot = true

  lifecycle {
    ignore_changes = [
      # Prevent drift on fields managed by the OS after first boot.
      initialization[0].user_account,
    ]
  }
}
