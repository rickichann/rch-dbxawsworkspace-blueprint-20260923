# ─── Identity / naming ───────────────────────────────────────────────────────
# Everything is named "${company_name}-dbx-${environment}-<suffix>".
company_name = "company"
environment  = "dev"

# ─── AWS ─────────────────────────────────────────────────────────────────────
aws_region  = "ap-southeast-3"
aws_profile = "rch"

# ─── Networking (dev) ────────────────────────────────────────────────────────
# Address space for the dev VPC only. The prod VPC is configured separately in
# ../../prod/aws-foundation/terraform.tfvars. See "CIDR allocation" in the repo
# root README for the full plan and why the ranges must not overlap.
#
# 10.175.0.0/16 = 10.175.0.0 - 10.175.255.255 (65,536 addresses)
vpc_cidr = "10.175.0.0/16"

# Public subnets host the NAT gateway. 256 addresses each.
public_subnet_cidrs = ["10.175.0.0/24", "10.175.1.0/24"]

# Private subnets host Databricks compute. 4,096 addresses each, which caps how
# many cluster nodes can run at once. Databricks requires at least two subnets
# in different AZs.
private_subnet_cidrs = ["10.175.16.0/20", "10.175.32.0/20"]

# One AZ per subnet, in the same order as the lists above.
availability_zones = ["ap-southeast-3a", "ap-southeast-3b"]

# ─── Tagging ─────────────────────────────────────────────────────────────────
# Environment and ManagedBy are added automatically.
common_tags = {
  Project            = "databricks"
  Platform           = "databricks"
  Owner              = "data-team"
  BusinessUnit       = "COMPANY"
  DataClassification = "internal"
}
