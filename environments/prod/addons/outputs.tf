output "ingress_ip" {
  value = data.azurerm_public_ip.ingress.ip_address
}

output "grafana_admin_password" {
  value     = random_password.grafana_admin.result
  sensitive = true
}
