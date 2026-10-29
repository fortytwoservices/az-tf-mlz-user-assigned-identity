# Subscription from ARM_SUBSCRIPTION_ID or the Azure CLI; credentials from the Azure CLI or OIDC.
provider "azapi" {}

locals {
  location = "swedencentral"
  # The repository the workflows run in. For a repository created, renamed or transferred after
  # 2026-07-15, GitHub's subjects also carry its IDs: "<owner>@<owner-id>/<repo>@<repo-id>".
  repository = "example-org/example-repo"
  tags       = { example = "github_actions" }
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  name      = "rg-mlz-uai-github-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = local.location

  response_export_values = []
  tags                   = local.tags
}

module "user_assigned_identity" {
  source = "../../"

  name      = "id-mlz-uai-github-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  # One credential per kind of workflow run: jobs that name the environment, and pull request runs.
  federated_identity_credentials = {
    github-production = {
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:${local.repository}:environment:production"
    }
    github-pull-request = {
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:${local.repository}:pull_request"
    }
  }
  lock = { kind = "CanNotDelete" }
  tags = local.tags
}
