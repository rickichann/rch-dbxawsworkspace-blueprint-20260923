locals {
  name = "${var.customer_name}-dbx-${var.environment}"

  tags = merge(var.common_tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  # Fall back to the name aws-foundation gives the bucket
  root_bucket = var.root_bucket_name != "" ? var.root_bucket_name : "${var.customer_name}-dbx-${var.environment}-root-bucket"
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Cross-account IAM Role for Databricks
# ─────────────────────────────────────────────────────────────────────────────

data "databricks_aws_assume_role_policy" "this" {
  provider    = databricks.mws
  external_id = var.databricks_account_id
}

data "databricks_aws_crossaccount_policy" "this" {
  provider = databricks.mws
}

resource "aws_iam_role" "cross_account" {
  name               = "${local.name}-cross-account-role"
  assume_role_policy = data.databricks_aws_assume_role_policy.this.json

  tags = local.tags
}

resource "aws_iam_role_policy" "cross_account" {
  name   = "${local.name}-cross-account-policy"
  role   = aws_iam_role.cross_account.id
  policy = data.databricks_aws_crossaccount_policy.this.json
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. Register credentials with Databricks (MWS)
# ─────────────────────────────────────────────────────────────────────────────

# Wait for IAM role to propagate before Databricks validates it
resource "time_sleep" "wait_for_iam" {
  depends_on      = [aws_iam_role_policy.cross_account]
  create_duration = "20s"
}

resource "databricks_mws_credentials" "this" {
  provider         = databricks.mws
  credentials_name = "${local.name}-credentials"
  role_arn         = aws_iam_role.cross_account.arn

  depends_on = [time_sleep.wait_for_iam]
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. S3 bucket policy for Databricks access
# ─────────────────────────────────────────────────────────────────────────────

data "databricks_aws_bucket_policy" "this" {
  provider = databricks.mws
  bucket   = local.root_bucket
}

resource "aws_s3_bucket_policy" "root_bucket" {
  bucket = local.root_bucket
  policy = data.databricks_aws_bucket_policy.this.json
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. Register storage configuration with Databricks (MWS)
# ─────────────────────────────────────────────────────────────────────────────

resource "databricks_mws_storage_configurations" "this" {
  provider                   = databricks.mws
  account_id                 = var.databricks_account_id
  storage_configuration_name = "${local.name}-storage"
  bucket_name                = local.root_bucket

  depends_on = [aws_s3_bucket_policy.root_bucket]
}

# ─────────────────────────────────────────────────────────────────────────────
# 5. Register network configuration with Databricks (MWS)
# ─────────────────────────────────────────────────────────────────────────────

resource "databricks_mws_networks" "this" {
  provider           = databricks.mws
  account_id         = var.databricks_account_id
  network_name       = "${local.name}-network"
  vpc_id             = var.vpc_id
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [var.security_group_id]
}

# ─────────────────────────────────────────────────────────────────────────────
# 6. Create the Databricks Workspace
# ─────────────────────────────────────────────────────────────────────────────

resource "databricks_mws_workspaces" "this" {
  provider       = databricks.mws
  account_id     = var.databricks_account_id
  workspace_name = local.name
  aws_region     = var.aws_region

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id
}
