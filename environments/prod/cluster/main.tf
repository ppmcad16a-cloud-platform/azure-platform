data "azurerm_client_config" "current" {}

# Read the outputs of the foundation stack (registry id etc.).
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

locals {
  tags = {
    Project   = "multicloud-capstone"
    ManagedBy = "terraform"
    Stack     = "prod-cluster"
  }
}

resource "azurerm_resource_group" "cluster" {
  name     = "rg-prod-cluster"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "../../../modules/network"

  name                = "prod"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  address_space       = ["10.20.0.0/16"]
  node_subnet_cidr    = "10.20.0.0/22"
  tags                = local.tags
}

module "aks" {
  source = "../../../modules/aks"

  name                = "prod-aks"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  vnet_id             = module.network.vnet_id
  subnet_id           = module.network.subnet_id
  egress_ip           = module.network.egress_ip
  admin_cidrs         = [var.admin_cidr]
  tenant_id           = data.azurerm_client_config.current.tenant_id
  admin_object_ids    = [data.azurerm_client_config.current.object_id] # you
  tags                = local.tags
}

# The nodes may PULL (only pull) images from our registry.
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = data.terraform_remote_state.foundation.outputs.acr_id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_object_id
}
