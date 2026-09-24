terraform {
  required_version = ">= 1.11.0"

  # Partial backend config: bucket, region and profile come from backend.hcl,
  # which is gitignored. Initialise with:
  #   terraform init -backend-config=backend.hcl
  # See backend.hcl.example in the repo root.
  backend "s3" {
    key          = "prod/aws-foundation/terraform.tfstate"
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
