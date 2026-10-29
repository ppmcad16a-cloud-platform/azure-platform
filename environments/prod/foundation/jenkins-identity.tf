# Azure identity that Jenkins (in GKE) becomes when deploying to AKS.
resource "azurerm_user_assigned_identity" "jenkins_deployer" {
  name                = "id-jenkins-deployer"
  location            = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name
  tags                = local.tags
}

# "Trust tokens from the prod-gke cluster, for jenkins/jenkins-deployer ONLY."
resource "azurerm_federated_identity_credential" "jenkins_from_gke" {
  name                = "gke-jenkins-deployer"
  resource_group_name = azurerm_resource_group.foundation.name
  parent_id           = azurerm_user_assigned_identity.jenkins_deployer.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://container.googleapis.com/v1/projects/project-899ced78-a554-40c2-96c/locations/asia-south1-a/clusters/prod-gke"
  subject             = "system:serviceaccount:jenkins:jenkins-deployer"
}

output "jenkins_deployer_client_id" {
  value = azurerm_user_assigned_identity.jenkins_deployer.client_id
}

output "jenkins_deployer_principal_id" {
  value = azurerm_user_assigned_identity.jenkins_deployer.principal_id
}
