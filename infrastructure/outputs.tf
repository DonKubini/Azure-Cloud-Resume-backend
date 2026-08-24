output "cosmosdb_endpoint" {
  description = "The endpoint URL for the Cosmos DB account"
  value       = azurerm_cosmosdb_account.cosmos.endpoint
}

output "function_app_url" {
  description = "The URL of the deployed Azure Function App"
  value       = "https://${azurerm_linux_function_app.fn_app.default_hostname}/api/GetResumeCounter"
}