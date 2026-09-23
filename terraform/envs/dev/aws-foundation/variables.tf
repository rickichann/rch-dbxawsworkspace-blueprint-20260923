# ─── Identity / naming ───────────────────────────────────────────────────────
# Every resource is named "${customer_name}-dbx-${environment}-<suffix>".
# Change these two values and the whole layer is rebranded.

variable "customer_name" {
  description = "Customer / org short name used as the prefix for every resource name. Lowercase letters, numbers and hyphens only (it ends up in S3 bucket names)."
  type        = string
  default     = "customer"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.customer_name))
    error_message = "customer_name must be lowercase alphanumeric with hyphens (S3-bucket safe)."
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
  default     = "ap-southeast-3"
}

variable "aws_profile" {
  description = "AWS CLI profile for the target account"
  type        = string
  default     = "customer-dev"
}

# ─── Networking ──────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR for the VPC. Must not overlap with other environments if you plan to peer them."
  type        = string
  default     = "10.175.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (NAT gateway lives in the first one)"
  type        = list(string)
  default     = ["10.175.0.0/24", "10.175.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets (Databricks compute). Databricks requires at least two, in different AZs."
  type        = list(string)
  default     = ["10.175.16.0/20", "10.175.32.0/20"]
}

variable "availability_zones" {
  description = "AZs to use. Must belong to aws_region and be at least as many as the subnet lists."
  type        = list(string)
  default     = ["ap-southeast-3a", "ap-southeast-3b"]
}

# ─── Tagging ─────────────────────────────────────────────────────────────────

variable "common_tags" {
  description = "Tags applied to every resource. Environment and ManagedBy are added automatically."
  type        = map(string)
  default = {
    Project            = "databricks"
    Platform           = "databricks"
    Owner              = "data-team"
    BusinessUnit       = "CUSTOMER"
    DataClassification = "internal"
  }
}
