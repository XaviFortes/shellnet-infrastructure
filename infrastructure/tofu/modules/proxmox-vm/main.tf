# infrastructure/tofu/modules/proxmox-vm/main.tf

resource "proxmox_virtual_environment_vm" "vm" {
  for_each = { for v in var.virtual_machines : v.name => v }

  node_name = var.node_name
  vm_id     = each.value.vmid
  name      = each.value.name
  tags      = try(each.value.tags, [])
  on_boot   = try(each.value.start_on_boot, false)

  description = "Managed by OpenTofu + Terragrunt"

  agent {
    enabled = true
    trim    = true
  }

  cpu {
    cores = each.value.cores
    type  = try(each.value.cpu_type, "host")
  }

  memory {
    dedicated = each.value.memory
    floating  = try(each.value.balloon, 0)
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    size         = tonumber(trimsuffix(tostring(each.value.disk_size), "G"))
    iothread     = true
    discard      = "on"
  }

  network_device {
    bridge   = var.network_bridge
    model    = "virtio"
    firewall = try(each.value.firewall, false)
  }

  operating_system {
    type = "l26"
  }

  initialization {
    user_account {
      keys = [var.ssh_public_keys]
    }
  }

  lifecycle {
    ignore_changes = [
      # Clone source — only used at creation, irrelevant for existing VMs.
      clone,
      # ip_config is managed inside the guest by cloud-init or static config.
      initialization[0].ip_config,
      # user_account drifts after first boot (cloud-init runs once).
      initialization[0].user_account,
      # cdrom / ide drives may be detached after install.
      cdrom,
      disk,
      # Description set by helper scripts — ignore drift.
      description,
      # Tags are overwritten by Proxmox Helper Scripts; track in config only.
      tags,
      # Runtime state — VMs may be stopped/started independently of IaC.
      started,
      on_boot,
      # SCSI hardware type is set at creation; changing it requires restart.
      scsi_hardware,
      # Tablet device is a default mismatch; not meaningful to enforce.
      tablet_device,
      # QEMU guest agent IP info — not reliably available via API token ACL.
      ipv4_addresses,
      ipv6_addresses,
      network_interface_names,
      # Agent block may not be installed on all VMs; avoid drift from config default.
      agent,
      # Keyboard layout is a UI preference; not meaningful to enforce.
      keyboard_layout,
      # initialization block (except user_account/ip_config above) managed in-guest.
      initialization,
      # serial_device may be present on cloud-image VMs; not managed here.
      serial_device,
      # network_device firewall is managed per-VM in Proxmox UI; not enforced here.
      network_device,
    ]
  }
}
