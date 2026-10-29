# ---------------------------------------------------------------
# who may touch the database backups (Azure Blob copy) -
# keyless: managed identities that trust GKE's identity tokens for ONE
# Kubernetes service account each (namespace "jenkins").
#   id-mongo-backup  : write new blobs only - custom role, NO read, NO delete
#                      (an overwrite keeps the old version: blob versioning)
#   id-mongo-restore : Storage Blob Data Reader - read/list only
# ---------------------------------------------------------------
locals {
  gke_issuer = "https://container.googleapis.com/v1/projects/project-899ced78-a554-40c2-96c/locations/asia-south1-a/clusters/prod-gke"
}

resource "azurerm_role_definition" "backup_writer" {
  name        = "MERN backup blob writer (no read, no delete)"
  scope       = azurerm_resource_group.foundation.id
  description = "Upload blobs to the backup container. Cannot read, list or delete."

  permissions {
    actions = []
    data_actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action",
    ]
  }

  assignable_scopes = [azurerm_resource_group.foundation.id]
}

resource "azurerm_user_assigned_identity" "dr" {
  for_each            = toset(["mongo-backup", "mongo-restore"])
  name                = "id-${each.key}"
  location            = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "dr" {
  for_each            = azurerm_user_assigned_identity.dr
  name                = "gke-${each.key}"
  resource_group_name = azurerm_resource_group.foundation.name
  parent_id           = each.value.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = local.gke_issuer
  subject             = "system:serviceaccount:jenkins:${each.key}"
}

resource "azurerm_role_assignment" "backup_writer" {
  scope              = azurerm_storage_container.backups.id
  role_definition_id = azurerm_role_definition.backup_writer.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.dr["mongo-backup"].principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "restore_reader" {
  scope                = azurerm_storage_container.backups.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.dr["mongo-restore"].principal_id
  principal_type       = "ServicePrincipal"
}

output "dr_client_ids" {
  value = { for k, id in azurerm_user_assigned_identity.dr : k => id.client_id }
}
