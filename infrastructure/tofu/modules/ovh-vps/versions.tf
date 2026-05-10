# infrastructure/tofu/modules/ovh-vps/versions.tf
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 0.46"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.0"
    }
  }
}
