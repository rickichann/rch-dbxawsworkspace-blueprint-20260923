locals {
  name = "${var.company_name}-dbx-${var.environment}"

  # Unity Catalog names are SQL identifiers. Hyphens force users to backtick-quote
  # them in every query (`company-dbx-prod-catalog`.raw.my_table), so use
  # underscores: company_dbx_prod.
  catalog_name = replace("${var.company_name}_dbx_${var.environment}", "-", "_")

  # S3 bucket names cannot contain underscores, so this one keeps hyphens.
  catalog_bucket = "${var.company_name}-dbx-${var.environment}-catalog-data"

  tags = merge(var.common_tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. S3 Bucket for Catalog Data
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "catalog_data" {
  bucket = local.catalog_bucket

  tags = merge(local.tags, {
    Name    = local.catalog_bucket
    Purpose = "unity-catalog-data"
  })
}

resource "aws_s3_bucket_versioning" "catalog_data" {
  bucket = aws_s3_bucket.catalog_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "catalog_data" {
  bucket = aws_s3_bucket.catalog_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "catalog_data" {
  bucket = aws_s3_bucket.catalog_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. IAM Role for Databricks to access the catalog bucket
# ─────────────────────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "catalog_data_access" {
  name = "${local.name}-catalog-data-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.databricks_aws_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.databricks_account_id
          }
        }
      },
      # Self-assume, required by Unity Catalog role validation
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.tags, {
    Purpose = "unity-catalog-data-access"
  })
}

resource "aws_iam_role_policy" "catalog_data_access" {
  name = "${local.name}-catalog-data-access-policy"
  role = aws_iam_role.catalog_data_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.catalog_data.arn,
          "${aws_s3_bucket.catalog_data.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name}-catalog-data-access-role"
        ]
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Databricks Storage Credential
# ─────────────────────────────────────────────────────────────────────────────

resource "databricks_storage_credential" "catalog" {
  name = "${local.name}-catalog-credential"

  aws_iam_role {
    role_arn = aws_iam_role.catalog_data_access.arn
  }

  comment = "Storage credential for ${local.catalog_name}"

  depends_on = [aws_iam_role_policy.catalog_data_access]
}

# Wait for IAM role to propagate before Databricks validates S3 access
resource "time_sleep" "wait_for_iam" {
  depends_on      = [databricks_storage_credential.catalog]
  create_duration = "20s"
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. Databricks External Location
# ─────────────────────────────────────────────────────────────────────────────

resource "databricks_external_location" "catalog" {
  name            = "${local.name}-catalog-location"
  url             = "s3://${aws_s3_bucket.catalog_data.bucket}"
  credential_name = databricks_storage_credential.catalog.name
  comment         = "External location for ${local.catalog_name}"

  depends_on = [time_sleep.wait_for_iam]
}

# ─────────────────────────────────────────────────────────────────────────────
# 5. Unity Catalog
# ─────────────────────────────────────────────────────────────────────────────

resource "databricks_catalog" "this" {
  name         = local.catalog_name
  comment      = "Unity Catalog for ${local.name}"
  storage_root = "s3://${aws_s3_bucket.catalog_data.bucket}/unity-catalog"

  # ISOLATED restricts the catalog to the workspaces bound below. Without this
  # the catalog is visible to every workspace sharing the metastore and the
  # databricks_workspace_binding resource has no effect.
  isolation_mode = "ISOLATED"

  properties = {
    purpose = var.environment
  }

  depends_on = [databricks_external_location.catalog]
}

# ─────────────────────────────────────────────────────────────────────────────
# 5b. Bind Catalog to Workspace
# ─────────────────────────────────────────────────────────────────────────────

resource "databricks_workspace_binding" "this" {
  securable_name = databricks_catalog.this.name
  securable_type = "catalog"
  workspace_id   = var.databricks_workspace_id
  binding_type   = "BINDING_TYPE_READ_WRITE"
}

# ─────────────────────────────────────────────────────────────────────────────
# 6. Schemas inside the Catalog
# ─────────────────────────────────────────────────────────────────────────────

resource "databricks_schema" "this" {
  for_each = toset(var.catalog_schemas)

  catalog_name = databricks_catalog.this.name
  name         = each.value
  comment      = "${each.value} schema for ${local.name}"

  properties = {
    purpose = each.value
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 7. Grants — allow all account users to use the catalog
# ─────────────────────────────────────────────────────────────────────────────

resource "databricks_grants" "catalog" {
  catalog = databricks_catalog.this.name

  grant {
    principal  = "account users"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT", "CREATE_SCHEMA", "CREATE_TABLE"]
  }
}
