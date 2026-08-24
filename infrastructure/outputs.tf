output "cosmosdb_endpoint" {
  description = "The endpoint URL for the Cosmos DB account"
  value       = azurerm_cosmosdb_account.cosmos.endpoint
}