# region.hcl — ovh
# Non-sensitive, provider-level values for OVH VPS cluster. Safe to commit.
#
# Discovered facts (2026-05-10):
#   - Location: Madrid LocalZone (MAD1)
#   - VPS plan: 4 vCPU (AMD EPYC Genoa), 8GB RAM, 75GB NVMe
#   - OS: Debian 13 (trixie), kernel 6.12.85+deb13-cloud-amd64
#   - Extra Longhorn volumes attached as block devices (sdc on .178: 5GB)
#   - No OVH metadata service reachable from inside (LocalZone behaviour)
#   - fail2ban running on all nodes
#   - No swap on any node
locals {
  region       = "ovh-eu"
  ovh_endpoint = "ovh-eu"
  zone         = "MAD1" # Madrid LocalZone
  provider     = "ovh"
  node_names   = ["vps-6b58f204", "vps-04483f6e", "vps-d147fb4d"]
  ssh_user     = "debian"
  os           = "debian13-64"
  vps_vcpus    = 4
  vps_ram_mb   = 8192
  vps_disk_gb  = 75
}
