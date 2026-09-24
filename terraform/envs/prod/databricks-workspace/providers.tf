terraform {
  required_version = ">= 1.11.0"

  # Partial backend config: bucket, region and profile come from backend.hcl,
  # which is gitignored. Initialise with:
  #   terraform init -backend-config=backend.hcl
  # See backend.hcl.example in the repo root.
  backend "s3" {
    key          = "prod/databricks-workspace/terraform.tfstate"
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

# Databricks provider at account level (for MWS APIs).
# Credentials come from TF_VAR_databricks_client_id / TF_VAR_databricks_client_secret.
provider "databricks" {
  alias      = "mws"
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id

  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}
