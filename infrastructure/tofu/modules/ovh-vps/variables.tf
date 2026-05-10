# infrastructure/tofu/modules/ovh-vps/variables.tf

variable "vps_instances" {
  description = "List of OVH VPS instances to manage."
  type = list(object({
    name        = string
    plan        = string
    os_template = string
    region      = string
  }))
}

variable "ssh_public_key" {
  description = "SSH public key to inject into each VPS."
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Name for the SSH key resource in OVH."
  type        = string
  default     = "homelab-key"
}

variable "ovh_endpoint" {
  description = "OVH API endpoint (e.g. ovh-eu)."
  type        = string
  default     = "ovh-eu"
}

variable "ovh_subsidiary" {
  description = "OVH subsidiary code (e.g. ES, FR, GB). Required by the ovh_vps resource."
  type        = string
  default     = "ES"
}
