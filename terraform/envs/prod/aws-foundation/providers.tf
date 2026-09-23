terraform {
  required_version = ">= 1.5.0"

  # ─── EDIT ME ───────────────────────────────────────────────────────────────
  # Backend settings cannot use variables. Replace "customer" with the customer
  # short name and make sure the bucket exists (see create-state-bucket.sh).
  backend "s3" {
    bucket  = "customer-dbx-prod-terraform-state"
    key     = "prod/aws-foundation/terraform.tfstate"
    region  = "ap-southeast-3"
    profile = "customer-prod"
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
