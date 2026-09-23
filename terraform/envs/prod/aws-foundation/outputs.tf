output "project_name" {
  description = "Resource name prefix used by this layer. Pass the same customer_name/environment to the other layers."
  value       = local.name
}

output "vpc_id" {
  description = "VPC ID (feed into databricks-workspace)"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (feed into databricks-workspace)"
  value       = aws_subnet.private[*].id
}

output "workspace_security_group_id" {
  description = "Security group ID (feed into databricks-workspace)"
  value       = aws_security_group.workspace.id
}

output "root_bucket_name" {
  description = "DBFS root bucket name (feed into databricks-workspace)"
  value       = aws_s3_bucket.root_bucket.bucket
}
