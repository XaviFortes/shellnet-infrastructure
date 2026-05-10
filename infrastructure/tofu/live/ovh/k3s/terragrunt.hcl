# terragrunt.hcl — ovh / k3s
# Configures the K3s HA cluster across the 3 OVH VPS nodes.
#
# Cluster facts (discovered 2026-05-10):
#   - K3s v1.33.5+k3s1
#   - 4 nodes: 3 OVH VPS (control-plane+etcd) + 1 homelab node (k3s-ha-ovh-es on almond)
#   - Roles on OVH nodes: control-plane, db, etcd, master, vps
#   - CNI: Flannel (pod CIDR 10.42.0.0/16)
#   - Storage: Longhorn (distributed across all 3 OVH nodes)
#   - Ingress: Traefik (LoadBalancer)
#
# Workloads running:
#   - argocd          GitOps controller
#   - cert-manager    TLS automation
#   - longhorn        Distributed block storage
#   - matrix          Matrix Synapse + bridges (mautrix-discord) + LiveKit + Coturn
#   - cnpg            CloudNativePG operator
#   - databases       Odoo PostgreSQL cluster
#   - redis           Redis HA
#   - lexus-telemetry Grafana + InfluxDB + Telegraf + Mosquitto (MQTT)
#   - frps            FRP server (reverse proxy/tunnel)
#   - roberbot        Custom bot deployment
include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vps" {
  config_path = "../vps"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vps_ips = {
      "vps-6b58f204" = "0.0.0.0"
      "vps-04483f6e" = "0.0.0.0"
      "vps-d147fb4d" = "0.0.0.0"
    }
  }
}

locals {
  node_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  _common_secrets = jsondecode(sops_decrypt_file("${get_parent_terragrunt_dir()}/common.sops.json"))
  _node_secrets   = jsondecode(sops_decrypt_file(find_in_parent_folders("secrets.sops.json")))
  secrets         = merge(local._common_secrets, local._node_secrets)
}

terraform {
  source = "../../../modules//k3s-cluster"
}

inputs = {
  cluster_name    = "ovh-k3s-ha"
  k3s_version     = "v1.33.5+k3s1"
  ssh_user        = local.node_vars.locals.ssh_user

  # All 3 OVH VPS act as control-plane + etcd nodes
  server_ips = [
    dependency.vps.outputs.vps_ips["vps-6b58f204"],
    dependency.vps.outputs.vps_ips["vps-04483f6e"],
    dependency.vps.outputs.vps_ips["vps-d147fb4d"],
  ]

  # The homelab k3s-ha-ovh-es VM (almond/2106) joins as a worker with role=homelab
  # Its join is managed separately via the almond/k3s terragrunt config.
  agent_ips = []

  k3s_token       = local.secrets.ovh_k3s_token
  kubeconfig_path = "~/.kube/ovh-k3s.yaml"

  # Flannel backend — matches existing cluster
  flannel_backend = "vxlan"
  pod_cidr        = "10.42.0.0/16"
  service_cidr    = "10.43.0.0/16"
}
