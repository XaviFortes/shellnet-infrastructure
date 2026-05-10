# terragrunt.hcl — peanut / kubeadm
# Provisions the Kubeadm cluster spread across peanut and almond.
# Control plane: almond/kadm-master (2108)
# Workers: almond/kadm-w1 (2109), almond/kubeadm-deb (2102), peanut/kubeadm-h2 (108)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vms" {
  config_path = "../vms"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vm_ips = { "kubeadm-h2" = "10.0.0.200" }
  }
}

locals {
  node_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  _common_secrets = jsondecode(sops_decrypt_file("${get_parent_terragrunt_dir()}/common.sops.json"))
  _node_secrets   = jsondecode(sops_decrypt_file(find_in_parent_folders("secrets.sops.json")))
  secrets         = merge(local._common_secrets, local._node_secrets)
}

terraform {
  source = "../../../modules//kubeadm-cluster"
}

inputs = {
  cluster_name       = "homelab-kubeadm"
  kubernetes_version = "1.30.0"

  # Control plane lives on almond — referenced by static reference, not dependency
  # (cross-node dependency is handled via Ansible, not Terragrunt)
  control_plane_ip = local.secrets.kubeadm_control_plane_ip

  worker_ips = [
    dependency.vms.outputs.vm_ips["kubeadm-h2"],
  ]

  pod_cidr     = "10.244.0.0/16"
  service_cidr = "10.96.0.0/12"

  kubeadm_token       = local.secrets.kubeadm_token
  kubeconfig_path     = "~/.kube/homelab-kubeadm.yaml"
}
