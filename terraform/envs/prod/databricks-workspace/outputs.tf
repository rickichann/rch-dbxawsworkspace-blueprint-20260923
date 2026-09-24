output "databricks_workspace_url" {
  description = "URL of the Databricks workspace (feed into databricks-catalog)"
  value       = databricks_mws_workspaces.this.workspace_url
}

output "databricks_workspace_id" {
  description = "ID of the Databricks workspace (feed into databricks-catalog)"
  value       = databricks_mws_workspaces.this.workspace_id
}

output "databricks_workspace_name" {
  description = "Name of the Databricks workspace"
  value       = databricks_mws_workspaces.this.workspace_name
}

output "databricks_credentials_id" {
  description = "Databricks credentials configuration ID"
  value       = databricks_mws_credentials.this.credentials_id
}

output "databricks_storage_config_id" {
  description = "Databricks storage configuration ID"
  value       = databricks_mws_storage_configurations.this.storage_configuration_id
}

output "databricks_network_id" {
  description = "Databricks network configuration ID"
  value       = databricks_mws_networks.this.network_id
}

output "cross_account_role_arn" {
  description = "ARN of the cross-account IAM role"
  value       = aws_iam_role.cross_account.arn
}

output "root_bucket_name" {
  description = "DBFS root bucket this workspace was registered with"
  value       = local.root_bucket
}

output "databricks_metastore_id" {
  description = "Unity Catalog metastore attached to this workspace, empty if the assignment was skipped"
  value       = var.databricks_metastore_id
}