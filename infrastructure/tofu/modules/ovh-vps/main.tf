# infrastructure/tofu/modules/ovh-vps/main.tf
# NOTE: OVH VPS resources are imported (not created fresh) since the servers
# already exist. Use `tofu import` to bring them under state management.
#
# Import commands (run once):
#   tofu import 'ovh_vps.vps["vps-6b58f204"]' vps-6b58f204.vps.ovh.net
#   tofu import 'ovh_vps.vps["vps-04483f6e"]' vps-04483f6e.vps.ovh.net
#   tofu import 'ovh_vps.vps["vps-d147fb4d"]' vps-d147fb4d.vps.ovh.net

# Data source to read IP addresses — the ovh_vps resource does not expose IPs.
data "ovh_vps" "vps_info" {
  for_each     = { for v in var.vps_instances : v.name => v }
  service_name = "${each.key}.vps.ovh.net"
  depends_on   = [ovh_vps.vps]
}

resource "ovh_vps" "vps" {
  for_each = { for v in var.vps_instances : v.name => v }

  # VPS name matches the OVH-assigned identifier
  # These fields are informational after import — OVH manages the actual hardware.
  display_name   = "${each.key}.vps.ovh.net"
  ovh_subsidiary = var.ovh_subsidiary

  lifecycle {
    # Prevent accidental destruction of production VPS via IaC mistake.
    prevent_destroy = true

    # OVH may update these fields independently — ignore drift on runtime values.
    # (service_name, name, iam are computed-only — provider-managed, no config to ignore)
    ignore_changes = [
      model,
      display_name,
      plan,
      monitoring_ip_blocks,
      sla_monitoring,
      state,
      netboot_mode,
      offer_type,
      memory_limit,
      vcore,
      zone,
      keymap,
    ]
  }
}
