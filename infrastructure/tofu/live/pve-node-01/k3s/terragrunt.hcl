# terragrunt.hcl — pve-node-01 / k3s
# Instantiates the k3s-cluster module for this node.
include "root" {
  path = find_in_parent_folders()
}

# Pull output from the VMs layer so we know which IPs were assigned.
dependency "vms" {
  config_path = "../vms"

  # Allows `terragrunt plan` to succeed before VMs exist (returns mock values).
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vm_ips = ["192.168.0.100", "192.168.0.101", "192.168.0.102"]
  }
}

terraform {
  source = "../../../modules//k3s-cluster"
}

inputs = {
  server_ips = dependency.vms.outputs.vm_ips
  k3s_version = "v1.30.0+k3s1"
  cluster_name = "homelab-k3s"
}
