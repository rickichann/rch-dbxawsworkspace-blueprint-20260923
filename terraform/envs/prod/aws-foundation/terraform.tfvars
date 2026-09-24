# ─── Identity / naming ───────────────────────────────────────────────────────
# Everything is named "${company_name}-dbx-${environment}-<suffix>".
company_name = "rch24company"
environment  = "prod"

# ─── AWS ─────────────────────────────────────────────────────────────────────
aws_region  = "ap-southeast-1"
aws_profile = "your-aws-profile"

# ─── Networking (prod) ─────────────────────────────────────────────────────────
# Supply your own ranges. Only the prefix sizes matter to this blueprint:
#
#   vpc_cidr              /16   65,536 addresses
#   public_subnet_cidrs   /24   one per AZ, carries the NAT gateway only
#   private_subnet_cidrs  /20   one per AZ, Databricks compute, ~4,000 usable
#                               addresses each, which caps concurrent cluster nodes
#
# The private subnets must sit in at least two different AZs; Databricks requires it.
# Ranges must not overlap each other, the other environment, or any network you
# might later connect to via peering, Transit Gateway or VPN. AWS refuses to peer
# overlapping VPCs, and renumbering afterwards means recreating the subnets, the
# Databricks network config and the workspace.
vpc_cidr = "REPLACE_ME/16"

public_subnet_cidrs  = ["REPLACE_ME/24", "REPLACE_ME/24"]
private_subnet_cidrs = ["REPLACE_ME/20", "REPLACE_ME/20"]

# Must belong to aws_region, and at least as many as the subnet lists above.
availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]
# ─── Tagging ─────────────────────────────────────────────────────────────────
# Environment and ManagedBy are added automatically.
common_tags = {
  Project            = "databricks"
  Platform           = "databricks"
  Owner              = "data-team"
  BusinessUnit       = "COMPANY"
  DataClassification = "internal"
}
