# infrastructure/tofu/modules/proxmox-lxc/outputs.tf

output "container_ids" {
  description = "Map of hostname → VMID for all created containers."
  value       = { for k, v in proxmox_virtual_environment_container.lxc : k => v.vm_id }
}

output "container_ips" {
  description = "Map of hostname → IP address (when using DHCP, check Proxmox UI)."
  value       = { for k, v in proxmox_virtual_environment_container.lxc : k => v.initialization[0].ip_config[0].ipv4[0].address }
}
