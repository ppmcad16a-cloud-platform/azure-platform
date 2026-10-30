# ---------------------------------------------------------------
# Stopped-standby failover: the identity GitHub Actions uses to WAKE the
# sleeping AKS cluster when GCP fails (platform-automation, workflow
# failover-wake). It may ONLY read the cluster and start it - not stop,
# change or delete it, and nothing inside it. Keyless: it trusts only the
# MAIN branch of platform-automation (immutable GitHub subject with ids).
# ---------------------------------------------------------------
locals {
  failover_subject = "repo:ppmcad16a-cloud-platform@308835253/platform-automation@1439349192:ref:refs/heads/main"
}

resource "azurerm_user_assigned_identity" "failover" {
  name                = "id-gha-failover"
  location            = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "failover" {
  name                = "github-platform-automation-main"
  resource_group_name = azurerm_resource_group.foundation.name
  parent_id           = azurerm_user_assigned_identity.failover.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = local.failover_subject
}

# Two permissions, nothing more. It is assigned on the cluster itself by the
# add-ons stack (the cluster only exists while a session runs).
resource "azurerm_role_definition" "aks_start" {
  name        = "MERN failover - start AKS"
  scope       = "/subscriptions/${var.subscription_id}"
  description = "Read an AKS cluster and start it. Nothing else."

  permissions {
    actions = [
      "Microsoft.ContainerService/managedClusters/read",
      "Microsoft.ContainerService/managedClusters/start/action",
    ]
  }

  assignable_scopes = ["/subscriptions/${var.subscription_id}"]
}

output "failover_client_id" {
  value = azurerm_user_assigned_identity.failover.client_id
}

output "failover_principal_id" {
  value = azurerm_user_assigned_identity.failover.principal_id
}

output "aks_start_role_id" {
  value = azurerm_role_definition.aks_start.role_definition_resource_id
}
