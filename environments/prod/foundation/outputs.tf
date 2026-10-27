output "acr_id" {
  value = azurerm_container_registry.this.id
}

output "acr_login_server" {
  description = "Images are pushed to <login_server>/<service>:<tag>"
  value       = azurerm_container_registry.this.login_server
}

output "key_vault_name" {
  value = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.this.vault_uri
}

output "backup_storage_account" {
  value = azurerm_storage_account.backups.name
}
