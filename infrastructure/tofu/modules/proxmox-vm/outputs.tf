# infrastructure/tofu/modules/proxmox-vm/outputs.tf

output "vm_ids" {
  description = "Map of VM name to vmid."
  value       = { for k, v in proxmox_virtual_environment_vm.vm : k => v.vm_id }
}

output "vm_ipv4_addresses" {
  description = "Map of VM name to IPv4 addresses (requires QEMU agent)."
  value       = { for k, v in proxmox_virtual_environment_vm.vm : k => try(v.ipv4_addresses, []) }
}
