terraform {
  required_version = ">= 1.5.0"

  # ─── EDIT ME ───────────────────────────────────────────────────────────────
  # Backend settings cannot use variables. Replace "company" with the company
  # short name and make sure the bucket exists (see create-state-bucket.sh).
  backend "s3" {
    bucket  = "company-dbx-prod-terraform-state"
    key     = "prod/databricks-catalog/terraform.tfstate"
    region  = "ap-southeast-3"
    profile = "company-prod"
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
