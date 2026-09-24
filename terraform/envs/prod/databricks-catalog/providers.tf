terraform {
  required_version = ">= 1.11.0"

  # Partial backend config: bucket, region and profile come from backend.hcl,
  # which is gitignored. Initialise with:
  #   terraform init -backend-config=backend.hcl
  # See backend.hcl.example in the repo root.
  backend "s3" {
    key          = "prod/databricks-catalog/terraform.tfstate"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.65.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Workspace-level provider (catalog, schemas, storage credential, external location)
provider "databricks" {
  host          = var.databricks_workspace_url
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}
