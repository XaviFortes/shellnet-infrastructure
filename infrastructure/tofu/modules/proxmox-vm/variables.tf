# infrastructure/tofu/modules/proxmox-vm/variables.tf

variable "virtual_machines" {
  description = "List of VM definitions to manage."
  type = list(object({
    name          = string
    vmid          = number
    cores         = number
    memory        = number
    disk_size     = string
    tags          = optional(list(string), [])
    balloon       = optional(number, 0)
    cpu_type      = optional(string, "host")
    start_on_boot = optional(bool, false)
    firewall      = optional(bool, false)
  }))
}

variable "node_name" {
  description = "The Proxmox node name."
  type        = string
}

variable "storage_pool" {
  description = "Storage pool for VM disks."
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Network bridge to attach VMs to."
  type        = string
  default     = "vmbr0"
}

variable "ssh_public_keys" {
  description = "SSH public keys to inject via cloud-init."
  type        = string
  sensitive   = true
}
