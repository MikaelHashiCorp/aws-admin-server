terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "aws-admin-server"
      Owner       = var.owner_name
      OwnerEmail  = var.owner_email
      Environment = "development"
      ManagedBy   = "terraform"
    }
  }
}

# Get current IP if allowlist_ip is not provided
data "http" "current_ip" {
  url = "https://ipinfo.io/ip"
}

locals {
  current_ip   = trimspace(data.http.current_ip.response_body)
  allowlist_ip = var.allowlist_ip != "" ? var.allowlist_ip : "${local.current_ip}/32"
}

module "admin_server" {
  source = "../modules"

  region               = var.region
  availability_zones   = var.availability_zones
  key_name             = var.key_name
  owner_name           = var.owner_name
  owner_email          = var.owner_email
  instance_name        = var.instance_name
  server_instance_type = var.server_instance_type
  allowlist_ip         = local.allowlist_ip
}
