# Subscription from ARM_SUBSCRIPTION_ID or the Azure CLI; credentials from the Azure CLI or OIDC.
provider "azapi" {}

locals {
  location = "swedencentral"
  tags     = { example = "default" }
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  name      = "rg-mlz-uai-default-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = local.location

  response_export_values = []
  tags                   = local.tags
}

module "user_assigned_identity" {
  source = "../../"

  name      = "id-mlz-uai-default-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  # A role on the identity: whoever runs this example may assign the identity to resources.
  role_assignments = {
    operator = {
      role_definition_id_or_name = "Managed Identity Operator"
      principal_id               = data.azapi_client_config.current.object_id
    }
  }
  tags = local.tags
}
