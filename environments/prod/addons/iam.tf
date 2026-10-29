# Key Vault created by the foundation stack.
data "terraform_remote_state" "foundation" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateo398md"
    container_name       = "tfstate"
    key                  = "prod/foundation.tfstate"
    subscription_id      = "9c0602c2-72a4-4432-a192-7abf998e2b60"
    tenant_id            = "0fd463ca-1b22-4674-bea5-699c2e0ad98b"
    use_azuread_auth     = true
  }
}

data "azurerm_key_vault" "mern" {
  name                = data.terraform_remote_state.foundation.outputs.key_vault_name
  resource_group_name = "rg-prod-foundation"
}

# An Azure identity just for External Secrets ...
resource "azurerm_user_assigned_identity" "eso" {
  name                = "id-prod-external-secrets"
  location            = data.azurerm_kubernetes_cluster.this.location
  resource_group_name = var.cluster_resource_group
}

# ... trusted ONLY when the token comes from THIS cluster, for the
# Kubernetes service account external-secrets/external-secrets.
resource "azurerm_federated_identity_credential" "eso" {
  name                = "prod-aks-external-secrets"
  resource_group_name = var.cluster_resource_group
  parent_id           = azurerm_user_assigned_identity.eso.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject             = "system:serviceaccount:external-secrets:external-secrets"
}

# ... and may READ only our app secrets, secret by secret.
resource "azurerm_role_assignment" "eso_read" {
  for_each             = toset(var.app_secret_names)
  scope                = "${data.azurerm_key_vault.mern.id}/secrets/${each.value}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.eso.principal_id
}

# Jenkins' identity may fetch this cluster's connection details - nothing else
# at Azure level. Inside the cluster it is limited to "mern" by Kubernetes RBAC.
resource "azurerm_role_assignment" "jenkins_cluster_user" {
  scope                = data.azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = data.terraform_remote_state.foundation.outputs.jenkins_deployer_principal_id
}
