output "cluster_name" {
  value = module.aks.cluster_name
}

output "egress_ip" {
  description = "Add this to the MongoDB Atlas IP access list (Phase 5)"
  value       = module.network.egress_ip
}

output "oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "get_credentials" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.cluster.name} --name ${module.aks.cluster_name} --overwrite-existing"
}
