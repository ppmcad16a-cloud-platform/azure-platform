terraform {
  required_version = ">= 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id     = var.subscription_id
  storage_use_azuread = true

  # The services we need are already registered (Phase 0/3), so skip the slow
  # automatic registration you saw during bootstrap.
  resource_provider_registrations = "none"
}
