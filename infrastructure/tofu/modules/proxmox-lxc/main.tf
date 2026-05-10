# infrastructure/tofu/modules/proxmox-lxc/main.tf

resource "proxmox_virtual_environment_container" "lxc" {
  for_each = { for c in var.lxc_containers : c.hostname => c }

  node_name    = var.node_name
  vm_id        = each.value.vmid
  tags         = each.value.tags
  unprivileged = try(each.value.unprivileged, true)

  description = "Managed by OpenTofu + Terragrunt"

  initialization {
    hostname = each.value.hostname

    ip_config {
      ipv4 {
        address = each.value.ip == "dhcp" ? "dhcp" : each.value.ip
        gateway = try(each.value.gateway, null)
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
    swap      = try(each.value.swap, 0)
  }

  disk {
    datastore_id = var.storage_pool
    size         = tonumber(trimsuffix(tostring(each.value.disk_size), "G"))
  }

  network_interface {
    name     = "eth0"
    bridge   = var.network_bridge
    firewall = try(each.value.firewall, false)
  }

  operating_system {
    template_file_id = try(each.value.template, null)
    type             = try(each.value.os_type, "debian")
  }

  start_on_boot = try(each.value.start_on_boot, true)

  dynamic "features" {
    for_each = try(each.value.features, null) != null ? [each.value.features] : []
    content {
      nesting = try(features.value.nesting, false)
    }
  }

  lifecycle {
    ignore_changes = [
      # template_file_id is only used at creation; the file may be removed
      # afterward. Ignoring prevents spurious replacement after import.
      operating_system[0].template_file_id,
      # Prevent drift on fields managed by the OS after first boot.
      initialization[0].user_account,
      # DNS is managed in-container, not via Proxmox API.
      initialization[0].dns,
      # Console settings are set by Proxmox defaults, not managed here.
      console,
      # IPv6 address managed separately (not in scope for this module).
      initialization[0].ip_config,
      # Description is set by Proxmox Helper Scripts at creation time; ignore drift.
      description,
      # Feature flags (keyctl, fuse, etc.) require root@pam — IaC token cannot change them.
      features,
    ]
  }
}
