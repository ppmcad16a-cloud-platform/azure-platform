terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateo398md"    
    container_name       = "tfstate"
    key                  = "bootstrap.tfstate"
    subscription_id      = "9c0602c2-72a4-4432-a192-7abf998e2b60"
    tenant_id            = "0fd463ca-1b22-4674-bea5-699c2e0ad98b"
    use_azuread_auth     = true # log in with Entra ID, not storage keys
  }
}
