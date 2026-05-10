# terragrunt.hcl — almond / k3s
# Provisions the K3s HA cluster hosted on almond.
# VM 2106 (k3s-ha-ovh-es) acts as the k3s server node.
# Additional agent nodes can be added to the server_ips list.
include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vms" {
  config_path = "../vms"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vm_ipv4_addresses = { "k3s-ha-ovh-es" = [["10.0.0.100"]] }
  }
}

locals {
  node_vars       = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  _common_secrets = jsondecode(sops_decrypt_file("${get_parent_terragrunt_dir()}/common.sops.json"))
  _node_secrets   = jsondecode(sops_decrypt_file(find_in_parent_folders("secrets.sops.json")))
  secrets         = merge(local._common_secrets, local._node_secrets)
}

terraform {
  source = "../../../modules//k3s-cluster"
}

inputs = {
  cluster_name    = "homelab-k3s"
  k3s_version     = "v1.30.0+k3s1"
  server_ips      = [dependency.vms.outputs.vm_ipv4_addresses["k3s-ha-ovh-es"][0][0]]
  agent_ips       = [] # extend when adding dedicated agents
  k3s_token       = local.secrets.ovh_k3s_token
  kubeconfig_path = "~/.kube/homelab-k3s.yaml"
}
