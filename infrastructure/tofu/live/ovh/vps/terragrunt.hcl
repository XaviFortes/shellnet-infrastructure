# terragrunt.hcl — ovh / vps
# Manages OVH VPS instances via the OVH Terraform provider.
# IPs are stored in SOPS — never in plaintext here.
#
# OVH provider docs: https://registry.terraform.io/providers/ovh/ovh/latest
#
# IMPORTANT: These VPS already exist (Madrid LocalZone, created manually).
# Use `tofu import` to bring them under state management — do NOT recreate.
#
# Import commands (one-time, run from this directory):
#   terragrunt import 'ovh_vps.vps["vps-6b58f204"]' vps-6b58f204.vps.ovh.net
#   terragrunt import 'ovh_vps.vps["vps-04483f6e"]' vps-04483f6e.vps.ovh.net
#   terragrunt import 'ovh_vps.vps["vps-d147fb4d"]' vps-d147fb4d.vps.ovh.net
#
# OVH API key setup:
#   The token needs path="/*" with GET to read VPS info.
#   Current token has path="" (root only) — needs to be recreated in OVH console
#   with routes: GET /vps, GET /vps/*, GET /me
include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  node_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  _common_secrets = jsondecode(sops_decrypt_file("${get_parent_terragrunt_dir()}/common.sops.json"))
  _node_secrets   = jsondecode(sops_decrypt_file(find_in_parent_folders("secrets.sops.json")))
  secrets         = merge(local._common_secrets, local._node_secrets)
}

terraform {
  source = "../../../modules//ovh-vps"
}

inputs = {
  ovh_endpoint   = local.node_vars.locals.ovh_endpoint
  ssh_public_key = local.secrets.ssh_public_key
  ssh_key_name   = "homelab-key"

  vps_instances = [
    {
      # vps-6b58f204: AMD EPYC Genoa 4vCPU / 8GB / 75GB — Madrid LocalZone
      # Running: K3s server, Longhorn (5GB extra volume), traefik svclb
      name        = "vps-6b58f204"
      plan        = "vps-le-2"
      os_template = local.node_vars.locals.os
      region      = local.node_vars.locals.zone
    },
    {
      # vps-04483f6e: AMD EPYC Genoa 4vCPU / 8GB / 75GB — Madrid LocalZone
      # Running: K3s server, WireGuard (wg0 / 10.8.0.1), livekit hostNetwork, wg-easy
      name        = "vps-04483f6e"
      plan        = "vps-le-2"
      os_template = local.node_vars.locals.os
      region      = local.node_vars.locals.zone
    },
    {
      # vps-d147fb4d: AMD EPYC Genoa 4vCPU / 8GB / 75GB — Madrid LocalZone
      # Running: K3s server, argocd-app-controller, grafana, influxdb
      name        = "vps-d147fb4d"
      plan        = "vps-le-2"
      os_template = local.node_vars.locals.os
      region      = local.node_vars.locals.zone
    },
  ]
}
