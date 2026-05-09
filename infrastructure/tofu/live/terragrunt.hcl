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
  node      = try(local.path_parts[1], "unknown-node")
  component = try(local.path_parts[2], "unknown-component")

  # Load the per-node region/node config (non-sensitive values only)
  node_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Load SOPS-encrypted secrets. The `sops_decrypt_file` function is a
  # Terragrunt built-in that calls `sops --decrypt` transparently.
  # The decrypted content is NEVER written to disk.
  secrets = jsondecode(sops_decrypt_file(find_in_parent_folders("secrets.sops.json")))

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
    # Remove or comment out for real AWS S3.
    endpoint                    = local.secrets.state_endpoint
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true

    # Enable state locking via a DynamoDB-compatible table (or Minio lock).
    # For Minio, use an external lock mechanism or set use_lockfile = true
    # (OpenTofu native locking, no DynamoDB required).
    use_lockfile = true
  }
}

# ---------------------------------------------------------------------------
# Generate a shared versions.tf in every child module's cache directory.
# Centralises provider version pinning in one place.
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
# Generate a shared provider.tf pulled from SOPS secrets.
# The Proxmox API token is injected here — never hardcoded.
# ---------------------------------------------------------------------------
generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "proxmox" {
      endpoint  = "${local.node_vars.locals.proxmox_endpoint}"
      api_token = "${local.secrets.proxmox_api_token}"
      insecure  = false

      ssh {
        agent    = true
        username = "${local.secrets.proxmox_ssh_user}"
      }
    }
  EOF
}

# ---------------------------------------------------------------------------
# Common inputs available to all child modules via dependency or direct use.
# ---------------------------------------------------------------------------
inputs = {
  node        = local.node
  component   = local.component
  common_tags = local.common_tags
}
