# Look up the existing Resource Group from Phase 1
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# Create a Cosmos DB account with Table API
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = var.cosmos_account_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  free_tier_enabled   = true

  capabilities {
    name = "EnableTable"
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = data.azurerm_resource_group.rg.location
    failover_priority = 0
  }
}

# Create a Cosmos DB Table
resource "azurerm_cosmosdb_table" "counter" {
  name                = "Counter"
  resource_group_name = data.azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  throughput          = 400
}

# Create a storage account required by the Function App
resource "azurerm_storage_account" "fn_storage" {
  name                     = var.function_storage_account_name
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create the Consumption Plan (Y1) for serverless pricing
resource "azurerm_service_plan" "fn_plan" {
  name                = "resume-function-plan"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "Y1" 
}

# Create the Linux Function App
resource "azurerm_linux_function_app" "fn_app" {
  name                       = var.function_app_name
  resource_group_name        = data.azurerm_resource_group.rg.name
  location                   = data.azurerm_resource_group.rg.location
  service_plan_id            = azurerm_service_plan.fn_plan.id
  storage_account_name       = azurerm_storage_account.fn_storage.name
  storage_account_access_key = azurerm_storage_account.fn_storage.primary_access_key

  site_config {
    application_stack {
      python_version = "3.12"
    }
    
    # CRITICAL: Configure CORS so your frontend can talk to this backend
    cors {
      allowed_origins = ["https://jakub-sisma.dev", "http://localhost:7071"]
    }
  }

  app_settings = {
    # Required for Python v2 model
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "AzureWebJobsFeatureFlags" = "EnableWorkerIndexing"
    
    # Dynamically build the Table API connection string using Cosmos DB outputs
    "COSMOS_CONNECTION_STRING" = "DefaultEndpointsProtocol=https;AccountName=${azurerm_cosmosdb_account.cosmos.name};AccountKey=${azurerm_cosmosdb_account.cosmos.primary_key};TableEndpoint=https://${azurerm_cosmosdb_account.cosmos.name}.table.cosmos.azure.com:443/;"

    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "ENABLE_ORYX_BUILD"              = "true"
  }
}