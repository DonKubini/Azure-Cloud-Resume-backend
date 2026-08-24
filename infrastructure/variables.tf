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