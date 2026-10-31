# The cluster's own identity. Created BEFORE the cluster so it can be given
# permission to use our network (Network Contributor) - least privilege:
# only on this VNet, nothing else.
resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "id-${var.name}-control-plane"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "control_plane_network" {
  scope                = var.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name
  sku_tier            = "Free" # control plane is free

  # Workload Identity: pods log in to Azure (e.g. Key Vault) WITHOUT secrets.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # No shared admin password: everyone logs in with Entra ID, and what they
  # may do is controlled by Azure roles (assigned below).
  local_account_disabled            = true
  role_based_access_control_enabled = true
  azure_active_directory_role_based_access_control {
    tenant_id          = var.tenant_id
    azure_rbac_enabled = true
  }

  # Only these IPs may talk to the Kubernetes API.
  api_server_access_profile {
    authorized_ip_ranges = concat(var.admin_cidrs, ["${var.egress_ip}/32"])
  }

  default_node_pool {
    name                        = "system"
    vm_size                     = var.vm_size
    node_count                  = var.node_count
    vnet_subnet_id              = var.subnet_id
    os_disk_size_gb             = var.os_disk_size_gb
    temporary_name_for_rotation = "tmpsystem"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"                # pods get IPs from a private overlay range
    network_data_plane  = "cilium"                 # modern, fast networking (eBPF)
    network_policy      = "cilium"                 # ENFORCES NetworkPolicies
    outbound_type       = "userAssignedNATGateway" # leave via our NAT + fixed IP
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.21.0.0/16"
    dns_service_ip      = "10.21.0.10"
  }

  tags = var.tags

  depends_on = [azurerm_role_assignment.control_plane_network]
}

# Give the listed people full admin rights INSIDE the cluster.
resource "azurerm_role_assignment" "cluster_admins" {
  for_each             = toset(var.admin_object_ids)
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.value
}
