# ─── Identity / naming ───────────────────────────────────────────────────────
# Every resource is named "${company_name}-dbx-${environment}-<suffix>".
# Change these two values and the whole layer is rebranded.

variable "company_name" {
  description = "Company / org short name used as the prefix for every resource name. Lowercase letters, numbers and hyphens only (it ends up in S3 bucket names)."
  type        = string
  default     = "company"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.company_name))
    error_message = "company_name must be lowercase alphanumeric with hyphens (S3-bucket safe)."
  }
}

variable "environment" {
  description = "Environment name. Part of every resource name and of the Environment tag."
  type        = string
  default     = "dev"
}

# ─── AWS ─────────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy in"
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_profile" {
  description = "AWS CLI profile for the target account"
  type        = string
  default     = "company-dev"
}

# ─── Networking ──────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR for the VPC. Expected size /16. No default: supply it per deployment so nothing is created under a placeholder range."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets, one per AZ. Expected size /24. These carry the NAT gateway only."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets, one per AZ. Expected size /20. These carry Databricks compute, so their size caps concurrent cluster nodes. Databricks requires at least two, in different AZs."
  type        = list(string)
}

variable "availability_zones" {
  description = "AZs to use. Must belong to aws_region and be at least as many as the subnet lists."
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

# ─── Tagging ─────────────────────────────────────────────────────────────────

variable "common_tags" {
  description = "Tags applied to every resource. Environment and ManagedBy are added automatically."
  type        = map(string)
  default = {
    Project            = "databricks"
    Platform           = "databricks"
    Owner              = "data-team"
    BusinessUnit       = "COMPANY"
    DataClassification = "internal"
  }
}
