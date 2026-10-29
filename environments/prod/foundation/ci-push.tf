# ---------------------------------------------------------------
# GitHub Actions pushes service images here - keyless.
# One identity, trusted ONLY for the main branch of the 7 service
# repos, allowed ONLY to push/pull on our registry (AcrPush).
# Note: Azure cannot add several federated credentials to one
# identity at the same time - apply with -parallelism=1.
# ---------------------------------------------------------------
locals {
  github_org = "ppmcad16a-cloud-platform"

  # GitHub writes PERMANENT ids into the identity card ("immutable subject"):
  #   repo:<org>@<org id>/<repo>@<repo id>:ref:refs/heads/main
  # A repo that is deleted and re-created under the same name gets a NEW id,
  # so it can never inherit these permissions.
  # Look up an id with:  gh api repos/<org>/<repo> --jq .id
  github_org_id = "308835253"
  github_repo_ids = {
    "api-gateway-service"  = "1363132826"
    "identity-service"     = "1347625227"
    "catalog-service"      = "1345164391"
    "commerce-service"     = "1363104512"
    "notification-service" = "1311276453"
    "client-service"       = "1363120914"
    "seed-db-service"      = "1363165699"
  }

  ci_services = [
    "api-gateway-service",
    "identity-service",
    "catalog-service",
    "commerce-service",
    "notification-service",
    "client-service",
    "seed-db-service",
  ]
}

resource "azurerm_user_assigned_identity" "ci_push" {
  name                = "id-gha-push"
  location            = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "ci_push" {
  for_each            = toset(local.ci_services)
  name                = "github-${each.value}-main"
  resource_group_name = azurerm_resource_group.foundation.name
  parent_id           = azurerm_user_assigned_identity.ci_push.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${local.github_org}@${local.github_org_id}/${each.value}@${local.github_repo_ids[each.value]}:ref:refs/heads/main"
}

resource "azurerm_role_assignment" "ci_push_acr" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.ci_push.principal_id
  principal_type       = "ServicePrincipal"
}

output "ci_push_client_id" {
  value = azurerm_user_assigned_identity.ci_push.client_id
}
