data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

locals {
  repo = "${var.github_org}/${var.github_repo}"
  tags = {
    Project   = "multicloud-capstone"
    ManagedBy = "terraform"
    Stack     = "bootstrap"
  }
}

# Storage account names must be globally unique -> random suffix.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "state" {
  name     = "rg-tfstate"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------
# 1. Terraform state storage
# ---------------------------------------------------------------
resource "azurerm_storage_account" "state" {
  name                            = "sttfstate${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false # nothing can ever be public
  shared_access_key_enabled       = false # no master keys - Entra ID logins only

  blob_properties {
    versioning_enabled = true # keep old versions of the state (undo button)
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  tags = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

# You (from this laptop) may read/write the state - needed for the
# "migrate state" step below.
resource "azurerm_role_assignment" "me_state" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ---------------------------------------------------------------
# 2. GitHub Actions login (OIDC) via managed identities
# ---------------------------------------------------------------
resource "azurerm_user_assigned_identity" "plan" {
  name                = "id-gha-${var.github_repo}-plan"
  resource_group_name = azurerm_resource_group.state.name
  location            = azurerm_resource_group.state.location
  tags                = local.tags
}

resource "azurerm_user_assigned_identity" "apply" {
  name                = "id-gha-${var.github_repo}-apply"
  resource_group_name = azurerm_resource_group.state.name
  location            = azurerm_resource_group.state.location
  tags                = local.tags
}

# "Trust GitHub's identity card, but only for pull requests of this repo."
resource "azurerm_federated_identity_credential" "plan" {
  name                = "github-pull-request"
  resource_group_name = azurerm_resource_group.state.name
  parent_id           = azurerm_user_assigned_identity.plan.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${local.repo}:pull_request"
}

# "... and only for the protected production environment."
resource "azurerm_federated_identity_credential" "apply" {
  name                = "github-environment-production"
  resource_group_name = azurerm_resource_group.state.name
  parent_id           = azurerm_user_assigned_identity.apply.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${local.repo}:environment:production"
}

# Plan robot: read everything, plus read/lock the state.
resource "azurerm_role_assignment" "plan_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.plan.principal_id
}

resource "azurerm_role_assignment" "plan_state" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.plan.principal_id
}

# Apply robot: create resources (Contributor) and give OTHER identities
# access, e.g. "AKS may pull from ACR" (RBAC Administrator).
# Deliberately NOT "Owner".
resource "azurerm_role_assignment" "apply_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.apply.principal_id
}

resource "azurerm_role_assignment" "apply_rbac_admin" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.apply.principal_id
}

resource "azurerm_role_assignment" "apply_state" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.apply.principal_id
}

# ---------------------------------------------------------------
# 3. Budget alert
# ---------------------------------------------------------------
resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "monthly-total"
  subscription_id = data.azurerm_subscription.current.id
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = [var.alert_email]
  }
}
