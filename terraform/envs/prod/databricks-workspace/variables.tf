# ─── Identity / naming ───────────────────────────────────────────────────────
# Must match the values used in aws-foundation.

variable "company_name" {
  description = "Company / org short name used as the prefix for every resource name."
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
  default     = "prod"
}

# ─── AWS ─────────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region (must be the region the VPC lives in)"
  type        = string
  default     = "ap-southeast-3"
}

variable "aws_profile" {
  description = "AWS CLI profile for the target account"
  type        = string
  default     = "company-prod"
}

# ─── Databricks account ──────────────────────────────────────────────────────

variable "databricks_account_id" {
  description = "Databricks account ID (accounts.cloud.databricks.com -> user menu)"
  type        = string
}

variable "databricks_client_id" {
  description = "Databricks account service principal client ID (OAuth). Set via TF_VAR_databricks_client_id."
  type        = string
}

variable "databricks_client_secret" {
  description = "Databricks account service principal secret (OAuth). Set via TF_VAR_databricks_client_secret."
  type        = string
  sensitive   = true
}

# ─── From aws-foundation outputs ─────────────────────────────────────────────

variable "vpc_id" {
  description = "VPC ID from aws-foundation output"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs from aws-foundation output (at least two, different AZs)"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID from aws-foundation output"
  type        = string
}

variable "root_bucket_name" {
  description = "DBFS root bucket name from aws-foundation output. Leave empty to derive it as \"{company_name}-dbx-{environment}-root-bucket\"."
  type        = string
  default     = ""
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
