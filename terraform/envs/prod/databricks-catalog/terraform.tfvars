# ─── Identity / naming ───────────────────────────────────────────────────────
# Must match aws-foundation/terraform.tfvars and databricks-workspace/terraform.tfvars.
company_name = "rch24company"
environment  = "prod"

# ─── AWS ─────────────────────────────────────────────────────────────────────
aws_region  = "ap-southeast-1"
aws_profile = "your-aws-profile"

# ─── Databricks account ──────────────────────────────────────────────────────
databricks_account_id = "REPLACE_WITH_DATABRICKS_ACCOUNT_ID"

# ─── From databricks-workspace outputs ───────────────────────────────────────
# Run in ../databricks-workspace:
#   terraform output databricks_workspace_url
#   terraform output databricks_workspace_id
databricks_workspace_url = "https://REPLACE_ME.cloud.databricks.com"
databricks_workspace_id  = "REPLACE_WITH_WORKSPACE_ID"

# OAuth credentials come from the environment:
#   $env:TF_VAR_databricks_client_id     = "your-client-id"
#   $env:TF_VAR_databricks_client_secret = "your-client-secret"

# ─── Schemas ─────────────────────────────────────────────────────────────────
catalog_schemas = ["raw", "curated", "analytics"]

# ─── Tagging ─────────────────────────────────────────────────────────────────
common_tags = {
  Project            = "databricks"
  Platform           = "databricks"
  Owner              = "data-team"
  BusinessUnit       = "COMPANY"
  DataClassification = "internal"
}
