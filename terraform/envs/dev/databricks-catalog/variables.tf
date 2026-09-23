# ─── Identity / naming ───────────────────────────────────────────────────────
# Must match the values used in aws-foundation and databricks-workspace.

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
  default     = "dev"
}

# ─── AWS ─────────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-3"
}

variable "aws_profile" {
  description = "AWS CLI profile for the target account"
  type        = string
  default     = "company-dev"
}

# ─── Databricks ──────────────────────────────────────────────────────────────

variable "databricks_account_id" {
  description = "Databricks account ID (used as the sts:ExternalId on the data access role)"
  type        = string
}

variable "databricks_workspace_url" {
  description = "Databricks workspace URL from the databricks-workspace output"
  type        = string
}

variable "databricks_workspace_id" {
  description = "Databricks workspace ID from the databricks-workspace output"
  type        = string
}

variable "databricks_client_id" {
  description = "Databricks service principal client ID (OAuth). Set via TF_VAR_databricks_client_id."
  type        = string
}

variable "databricks_client_secret" {
  description = "Databricks service principal secret (OAuth). Set via TF_VAR_databricks_client_secret."
  type        = string
  sensitive   = true
}

variable "databricks_aws_account_id" {
  description = "AWS account ID owned by Databricks that assumes the Unity Catalog data access role. 414351767826 for all commercial AWS regions."
  type        = string
  default     = "414351767826"
}

# ─── Catalog ─────────────────────────────────────────────────────────────────

variable "catalog_schemas" {
  description = "Schemas to create inside the catalog"
  type        = list(string)
  default     = ["raw", "curated", "analytics"]
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
