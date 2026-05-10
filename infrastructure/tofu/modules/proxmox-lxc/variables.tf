# infrastructure/tofu/modules/proxmox-lxc/variables.tf

variable "lxc_containers" {
  description = "List of LXC container definitions to create."
  type = list(object({
    hostname      = string
    vmid          = number
    cores         = number
    memory        = number
    disk_size     = string
    ip            = string
    gateway       = optional(string, null)
    os_type       = optional(string, "debian")
    template      = optional(string, null)
    tags          = optional(list(string), [])
    swap          = optional(number, 0)
    unprivileged  = optional(bool, true)
    start_on_boot = optional(bool, true)
    firewall      = optional(bool, false)
    features = optional(object({
      nesting = optional(bool, false)
    }), null)
  }))
}

variable "node_name" {
  description = "The Proxmox node name to deploy containers on."
  type        = string
}

variable "storage_pool" {
  description = "Storage pool for container rootfs."
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Network bridge to attach containers to."
  type        = string
  default     = "vmbr0"
}

variable "common_tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "ssh_public_keys" {
  description = "SSH public keys to inject into containers."
  type        = string
  sensitive   = true
}
