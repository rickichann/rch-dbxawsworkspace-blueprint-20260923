output "catalog_name" {
  description = "Name of the Unity Catalog"
  value       = databricks_catalog.this.name
}

output "catalog_id" {
  description = "ID of the Unity Catalog"
  value       = databricks_catalog.this.id
}

output "catalog_bucket_name" {
  description = "S3 bucket name for catalog data"
  value       = aws_s3_bucket.catalog_data.bucket
}

output "catalog_storage_root" {
  description = "Storage root path for the catalog"
  value       = "s3://${aws_s3_bucket.catalog_data.bucket}/unity-catalog"
}

output "storage_credential_name" {
  description = "Name of the Databricks storage credential"
  value       = databricks_storage_credential.catalog.name
}

output "external_location_name" {
  description = "Name of the Databricks external location"
  value       = databricks_external_location.catalog.name
}

output "data_access_role_arn" {
  description = "ARN of the IAM role for catalog data access"
  value       = aws_iam_role.catalog_data_access.arn
}

output "schema_names" {
  description = "Names of the schemas created"
  value       = [for s in databricks_schema.this : s.name]
}
