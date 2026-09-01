output "cosmosdb_endpoint" {
  description = "The endpoint URL for the Cosmos DB account"
  value       = azurerm_cosmosdb_account.cosmos.endpoint
}

output "function_app_url" {
  description = "The URL of the deployed Azure Function App"
  value       = "https://${azurerm_linux_function_app.fn_app.default_hostname}/api/GetResumeCounter"
}

output "AZURE_CLIENT_ID" {
  value = azurerm_user_assigned_identity.github_identity.client_id
}
output "AZURE_TENANT_ID" {
  value = data.azurerm_client_config.current.tenant_id
}
output "AZURE_SUBSCRIPTION_ID" {
  value = data.azurerm_client_config.current.subscription_id
}