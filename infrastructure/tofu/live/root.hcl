# =============================================================================
# ROOT terragrunt.hcl
# This is the single source of truth for:
#   - Remote state backend configuration
#   - Provider version pinning
#   - Common inputs passed to all child modules
# =============================================================================

# ---------------------------------------------------------------------------
# Local values derived from directory conventions:
#   live/<node>/<component>/terragrunt.hcl
# ---------------------------------------------------------------------------
locals {
  # Parse the directory path to extract node and component names automatically.
  # This avoids hardcoding environment names in every child config.
  path_parts = split("/", path_relative_to_include())

  # Convention: live/<node>/<component>
  # path_relative_to_include() returns "almond/lxc" from the child's perspective
  # so path_parts[0] = node, path_parts[1] = component
  node      = try(local.path_parts[0], "unknown-node")
  component = try(local.path_parts[1], "unknown-component")

  # Load the per-node region/node config (non-sensitive values only)
  node_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # ---------------------------------------------------------------------------
  # Secrets loading — two-layer merge:
  #   1. common.sops.json  — shared across ALL nodes (B2 state creds, SSH key,
  #                          Proxmox IaC token, OVH API creds, OVH K3s token)
  #   2. secrets.sops.json — per-node unique values (kubeadm IP, etc.)
  #
  # Per-node values WIN on key collision (merge puts node last).
  # `sops_decrypt_file` is a Terragrunt built-in; decrypted content is NEVER
  # written to disk.
  #
  # get_parent_terragrunt_dir() resolves to the directory containing THIS file
  # (live/), so common.sops.json is always found at live/common.sops.json
  # regardless of how deep the child module is.
  # ---------------------------------------------------------------------------
  _common_secrets = jsondecode(sops_decrypt_file("${get_parent_terragrunt_dir()}/common.sops.json"))
  _node_secrets   = jsondecode(sops_decrypt_file(find_in_parent_folders("secrets.sops.json")))
  secrets         = merge(local._common_secrets, local._node_secrets)

  # Detect which provider stack to use based on the node directory name.
  # Proxmox nodes: almond, peanut
  # OVH MAD LocalZone: ovh
  # OVH GRA standard:  ovh-gra
  is_proxmox = contains(["almond", "peanut"], local.node)
  is_ovh     = contains(["ovh", "ovh-gra"], local.node)

  # Provider content built as a string so it can be used in a single generate block.
  # HCL heredocs cannot appear in ternary expressions, so we use format() instead.
  _proxmox_provider = local.is_proxmox ? format(
    "provider \"proxmox\" {\n  endpoint  = \"%s\"\n  api_token = \"%s\"\n  insecure  = true\n\n  ssh {\n    agent    = true\n    username = \"%s\"\n  }\n}\n",
    local.node_vars.locals.proxmox_endpoint,
    local.secrets.proxmox_api_token,
    local.secrets.proxmox_ssh_user,
  ) : ""
  _ovh_provider = local.is_ovh ? format(
    "provider \"ovh\" {\n  endpoint           = \"ovh-eu\"\n  application_key    = \"%s\"\n  application_secret = \"%s\"\n  consumer_key       = \"%s\"\n}\n",
    local.secrets.ovh_application_key,
    local.secrets.ovh_application_secret,
    local.secrets.ovh_consumer_key,
  ) : ""
  provider_contents = local.is_proxmox ? local._proxmox_provider : (local.is_ovh ? local._ovh_provider : "# No provider for node: ${local.node}\n")

  # Common tags applied to all resources
  common_tags = {
    managed_by  = "opentofu+terragrunt"
    node        = local.node
    component   = local.component
    repo        = "github.com/<YOUR_USERNAME>/homelab"
  }
}

# ---------------------------------------------------------------------------
# Remote State — S3-compatible backend (Minio, Cloudflare R2, AWS S3, etc.)
# State is stored remotely so it is NEVER committed to this repository.
# ---------------------------------------------------------------------------
remote_state {
  backend = "s3"

  # Generate a backend.tf in the .terragrunt-cache directory at plan/apply time.
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  # Terragrunt-level flags — consumed by Terragrunt, NOT written to backend.tf.
  # Backblaze B2 does not implement GetBucketAcl, GetBucketEncryption,
  # GetBucketVersioning, GetBucketPolicy, or STS. Skip all unsupported calls.
  disable_init          = false
  disable_bucket_update = true

  config = {
    # ---------------------------------------------------------------------------
    # SENSITIVE VALUES — pulled from SOPS-encrypted secrets, never hardcoded.
    # ---------------------------------------------------------------------------
    bucket     = local.secrets.state_bucket_name
    access_key = local.secrets.state_access_key
    secret_key = local.secrets.state_secret_key

    # ---------------------------------------------------------------------------
    # NON-SENSITIVE — path derived from directory convention, safe to be here.
    # ---------------------------------------------------------------------------
    # Unique state key per node+component prevents state collisions.
    key    = "homelab/${local.node}/${local.component}/tofu.tfstate"
    region = local.node_vars.locals.region

    # For Minio or other S3-compatible stores, set this to your endpoint.
    # Ensure https:// scheme is present — some vaults store the bare hostname.
    endpoint                    = startswith(local.secrets.state_endpoint, "http") ? local.secrets.state_endpoint : "https://${local.secrets.state_endpoint}"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true

    # Backblaze B2 does not implement these S3 APIs — skip the checks.
    # These are valid OpenTofu S3 backend arguments (not Terragrunt-only).
    skip_bucket_root_access    = true
    skip_bucket_enforced_tls   = true
    skip_requesting_account_id = true

    # Backblaze B2 does not support OpenTofu's native file-based locking.
    # For a solo operator this is acceptable.
    use_lockfile = false
  }
}

# ---------------------------------------------------------------------------
# Generate versions.tf — includes all providers; each module only uses
# the ones it declares. Unused providers are never initialised.
# ---------------------------------------------------------------------------
generate "versions" {
  path      = "versions_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.7.0"

      required_providers {
        proxmox = {
          source  = "bpg/proxmox"
          version = "~> 0.60"
        }
        ovh = {
          source  = "ovh/ovh"
          version = "~> 0.46"
        }
        sops = {
          source  = "carlpett/sops"
          version = "~> 1.0"
        }
        random = {
          source  = "hashicorp/random"
          version = "~> 3.6"
        }
        tls = {
          source  = "hashicorp/tls"
          version = "~> 4.0"
        }
      }
    }
  EOF
}

# ---------------------------------------------------------------------------
# Generate provider.tf — conditionally emits the right provider block.
# Contents are built as a local string (format()) because HCL heredocs
# cannot be used inside ternary expressions.
# Proxmox API token and OVH credentials come from SOPS; never hardcoded.
# ---------------------------------------------------------------------------
generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = local.provider_contents
}

# ---------------------------------------------------------------------------
# Common inputs available to all child modules via dependency or direct use.
# ---------------------------------------------------------------------------
inputs = {
  node        = local.node
  component   = local.component
  common_tags = local.common_tags
}
