# infrastructure/tofu/modules/ovh-vps/outputs.tf

output "vps_ips" {
  description = "Map of VPS name → primary IP. Used by k3s module as server_ips."
  # IPs come from OVH state — never hardcoded, never in plaintext in the repo.
  value     = { for k, v in data.ovh_vps.vps_info : k => tolist(v.ips)[0] }
  sensitive = true # marks the output as sensitive so it's never printed in CI logs
}

output "vps_names" {
  description = "List of OVH VPS hostnames."
  value       = [for v in data.ovh_vps.vps_info : v.displayname]
}
