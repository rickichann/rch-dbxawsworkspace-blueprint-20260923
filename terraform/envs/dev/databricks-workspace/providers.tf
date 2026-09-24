terraform {
  required_version = ">= 1.11.0"

  # ─── EDIT ME ───────────────────────────────────────────────────────────────
  # Backend settings cannot use variables. Replace "company" with the company
  # short name and make sure the bucket exists (see create-state-bucket.sh).
  backend "s3" {
    bucket       = "company-dbx-dev-terraform-state"
    key          = "dev/databricks-workspace/terraform.tfstate"
    region       = "ap-southeast-3"
    profile      = "rch"
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
