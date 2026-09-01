variable "cosmos_account_name" {
  description = "Name of the Cosmos DB account (must be globally unique, lowercase letters and numbers only)"
  type        = string
  default     = "js-cloud-resume-db"
}

variable "resource_group_name" {
  description = "Name of the existing Resource Group"
  type        = string
  default     = "cloud-resume-rg"
}

variable "function_storage_account_name" {
  description = "Name of the storage account for the function app (must be globally unique)"
  type        = string
  default     = "jscloudresumeacct2026be"
}

variable "function_app_name" {
  description = "Name of the Azure Function App (must be globally unique)"
  type        = string
  default     = "jscloudresumeapp2026"
}

variable "github_repository" {
  description = "The GitHub repository in the format of Organization/Repository (e.g., your-username/azure-resume-backend)"
  type        = string
  default     = "DonKubini@128520245/Azure-Cloud-Resume-backend@1341805137"
}