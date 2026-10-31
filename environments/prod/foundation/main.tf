data "azurerm_client_config" "current" {}

locals {
  tags = {
    Project   = "multicloud-capstone"
    ManagedBy = "terraform"
    Stack     = "prod-foundation"
  }
}

# Registry / Key Vault / storage names must be globally unique.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "foundation" {
  name     = "rg-prod-foundation"
  location = var.location
  tags     = local.tags
}

# Private container registry for our service images.
resource "azurerm_container_registry" "this" {
  name                = "acrmern${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.foundation.name
  location            = azurerm_resource_group.foundation.location
  sku                 = "Basic"
  admin_enabled       = false # no shared username/password - identities only
  tags                = local.tags
}

# The "vault" for this cloud: app secrets (MongoDB key, JWT secret) go here
# by global-platform and are read by the cluster with Workload Identity.
resource "azurerm_key_vault" "this" {
  name                       = "kv-mern-${random_string.suffix.result}"
  location                   = azurerm_resource_group.foundation.location
  resource_group_name        = azurerm_resource_group.foundation.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true  # access controlled by Azure roles, not vault policies
  soft_delete_retention_days = 7     # a deleted vault can be recovered for 7 days
  purge_protection_enabled   = false # so we can delete it fully if needed
  tags                       = local.tags
}

# You may manage secrets in the vault (global-platform writes them).
resource "azurerm_role_assignment" "me_kv_secrets" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Database backups: private, no storage keys, versioned.
resource "azurerm_storage_account" "backups" {
  name                            = "stbackup${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.foundation.name
  location                        = azurerm_resource_group.foundation.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false

  blob_properties {
    versioning_enabled = true
  }

  tags = local.tags
}

resource "azurerm_storage_container" "backups" {
  name                  = "mongo-backups"
  storage_account_id    = azurerm_storage_account.backups.id
  container_access_type = "private"
}

# Delete backups (and old versions) after 30 days.
resource "azurerm_storage_management_policy" "backups" {
  storage_account_id = azurerm_storage_account.backups.id

  rule {
    name    = "delete-after-30-days"
    enabled = true
    filters {
      blob_types = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 30
      }
      version {
        delete_after_days_since_creation = 30
      }
    }
  }
}
