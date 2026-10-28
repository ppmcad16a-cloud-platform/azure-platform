provider "azurerm" {
  features {}
  subscription_id                 = var.subscription_id
  storage_use_azuread             = true
  resource_provider_registrations = "none"
}

data "azurerm_client_config" "current" {}

data "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  resource_group_name = var.cluster_resource_group
}

# Helm logs in like kubectl does: kubelogin turns your "az login" into a
# Kubernetes token. "6dae42f8-..." is the fixed ID of the AKS sign-in
# application (the same for every AKS cluster).
provider "helm" {
  kubernetes = {
    host                   = data.azurerm_kubernetes_cluster.this.kube_config[0].host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args        = ["get-token", "--login", "azurecli", "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630"]
    }
  }
}
