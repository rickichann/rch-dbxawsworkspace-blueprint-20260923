#!/bin/bash
# Creates the S3 bucket that holds Terraform remote state for this environment.
# Safe to re-run: it exits early if the bucket already exists.
set -euo pipefail

# ─── EDIT ME ─────────────────────────────────────────────────────────────────
COMPANY_NAME="company"
ENVIRONMENT="dev"
REGION="ap-southeast-3"
PROFILE="rch"
# ─────────────────────────────────────────────────────────────────────────────

BUCKET_NAME="${COMPANY_NAME}-dbx-${ENVIRONMENT}-terraform-state"

if aws s3api head-bucket --bucket "${BUCKET_NAME}" --profile "${PROFILE}" 2>/dev/null; then
  echo "Bucket '${BUCKET_NAME}' already exists, skipping creation."
else
  echo "Creating S3 bucket: ${BUCKET_NAME}"
  if [ "${REGION}" = "us-east-1" ]; then
    # us-east-1 rejects a LocationConstraint
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${REGION}" \
      --profile "${PROFILE}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}" \
      --profile "${PROFILE}"
  fi
fi

echo "Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled \
  --profile "${PROFILE}"

echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
  --profile "${PROFILE}"

echo "Enabling server-side encryption (KMS)..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "aws:kms"
        },
        "BucketKeyEnabled": true
      }
    ]
  }' \
  --profile "${PROFILE}"

echo "Tagging bucket..."
aws s3api put-bucket-tagging \
  --bucket "${BUCKET_NAME}" \
  --tagging '{
    "TagSet": [
      {"Key": "Name", "Value": "'"${BUCKET_NAME}"'"},
      {"Key": "Project", "Value": "databricks"},
      {"Key": "Environment", "Value": "'"${ENVIRONMENT}"'"},
      {"Key": "ManagedBy", "Value": "aws-cli"},
      {"Key": "Purpose", "Value": "terraform-state"}
    ]
  }' \
  --profile "${PROFILE}"

echo "Done. State bucket '${BUCKET_NAME}' is ready."
echo "State locking needs no extra setup: Terraform writes a <key>.tflock object"
echo "into this same bucket during a run. Whoever applies needs s3:PutObject and"
echo "s3:DeleteObject on it, which they already have for the state file itself."
echo ""
echo "Use it in each layer's providers.tf backend block:"
echo "  bucket  = \"${BUCKET_NAME}\""
echo "  key     = \"${ENVIRONMENT}/<layer>/terraform.tfstate\""
echo "  region  = \"${REGION}\""
echo "  profile = \"${PROFILE}\""
echo "  use_lockfile = true"
