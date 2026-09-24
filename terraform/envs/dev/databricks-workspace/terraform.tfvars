# ─── Identity / naming ───────────────────────────────────────────────────────
# Must match aws-foundation/terraform.tfvars.
company_name = "rch24company"
environment  = "dev"

# ─── AWS ─────────────────────────────────────────────────────────────────────
aws_region  = "ap-southeast-1"
aws_profile = "your-aws-profile"

# ─── Databricks account ──────────────────────────────────────────────────────
# Find your account ID at https://accounts.cloud.databricks.com
databricks_account_id = "REPLACE_WITH_DATABRICKS_ACCOUNT_ID"

# OAuth service principal credentials are NOT set here. Export them instead:
#   $env:TF_VAR_databricks_client_id     = "your-client-id"
#   $env:TF_VAR_databricks_client_secret = "your-client-secret"

# ─── From aws-foundation outputs ─────────────────────────────────────────────
# Run `terraform output` in ../aws-foundation and paste the values here.
vpc_id             = "vpc-REPLACE_ME"
private_subnet_ids = ["subnet-REPLACE_ME_A", "subnet-REPLACE_ME_B"]
security_group_id  = "sg-REPLACE_ME"

# Leave empty to derive "{company_name}-dbx-{environment}-root-bucket"
root_bucket_name = ""

# ─── Tagging ─────────────────────────────────────────────────────────────────
common_tags = {
  Project            = "databricks"
  Platform           = "databricks"
  Owner              = "data-team"
  BusinessUnit       = "COMPANY"
  DataClassification = "internal"
}

# ─── Unity Catalog ───────────────────────────────────────────────────────────
# Regional metastore, attached to this workspace by the layer 2 apply.
databricks_metastore_id = "REPLACE_WITH_METASTORE_ID"