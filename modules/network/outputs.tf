output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "subnet_id" {
  # Only hand out the subnet id once the NAT gateway is attached to it.
  value      = azurerm_subnet.nodes.id
  depends_on = [azurerm_subnet_nat_gateway_association.nodes]
}

output "egress_ip" {
  value = azurerm_public_ip.egress.ip_address
}
