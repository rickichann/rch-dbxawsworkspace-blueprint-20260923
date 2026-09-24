terraform {
  required_version = ">= 1.11.0"

  # ─── EDIT ME ───────────────────────────────────────────────────────────────
  # Backend settings cannot use variables. Replace "company" with the company
  # short name and make sure the bucket exists (see create-state-bucket.sh).
  backend "s3" {
    bucket       = "company-dbx-prod-terraform-state"
    key          = "prod/aws-foundation/terraform.tfstate"
    region       = "ap-southeast-3"
    profile      = "company-prod"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}
