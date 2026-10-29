data "azurerm_public_ip" "ingress" {
  name                = "pip-prod-ingress"
  resource_group_name = var.cluster_resource_group
}

data "http" "cloudflare_ipv4" {
  url = "https://www.cloudflare.com/ips-v4"
}

locals {
  cloudflare_cidrs = [
    for line in split("\n", trimspace(data.http.cloudflare_ipv4.response_body)) :
    trimspace(line) if trimspace(line) != ""
  ]
}

resource "helm_release" "envoy_gateway" {
  name             = "envoy-gateway"
  repository       = "oci://docker.io/envoyproxy"
  chart            = "gateway-helm"
  version          = var.envoy_gateway_version
  namespace        = "envoy-gateway-system"
  create_namespace = true
  wait             = true
  timeout          = 600
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.external_secrets_version
  namespace        = "external-secrets"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    serviceAccount = {
      # Which Azure identity this Kubernetes service account represents.
      annotations = {
        "azure.workload.identity/client-id" = azurerm_user_assigned_identity.eso.client_id
        "azure.workload.identity/tenant-id" = data.azurerm_client_config.current.tenant_id
      }
    }
  })]

  depends_on = [azurerm_federated_identity_credential.eso]
}

resource "helm_release" "platform_config" {
  name      = "platform-config"
  chart     = "${path.module}/charts/platform-config"
  namespace = "envoy-gateway-system"
  wait      = true

  values = [yamlencode({
    cloud = "azure"
    # Azure: name the existing IP resource instead of giving the address.
    serviceAnnotations = {
      "service.beta.kubernetes.io/azure-load-balancer-resource-group" = var.cluster_resource_group
      "service.beta.kubernetes.io/azure-pip-name"                     = data.azurerm_public_ip.ingress.name
      # Health-check the HTTPS port as plain TCP (an HTTP check on "/"
      # would get a 404 from Envoy and mark the node unhealthy).
      "service.beta.kubernetes.io/port_443_health-probe_protocol" = "Tcp"
    }
    sourceRanges = concat(local.cloudflare_cidrs, [var.admin_cidr])
    secretStore = {
      azurekv = {
        authType = "WorkloadIdentity"
        vaultUrl = data.azurerm_key_vault.mern.vault_uri
        serviceAccountRef = {
          name      = "external-secrets"
          namespace = "external-secrets"
        }
      }
    }
    # In AKS, an Entra identity's Kubernetes user name is its object ID.
    deployerSubjects = [
      {
        kind     = "User"
        apiGroup = "rbac.authorization.k8s.io"
        name     = data.terraform_remote_state.foundation.outputs.jenkins_deployer_principal_id
      },
    ]

  })]

  depends_on = [
    helm_release.envoy_gateway,
    helm_release.external_secrets,
    azurerm_role_assignment.eso_read,
  ]
}
