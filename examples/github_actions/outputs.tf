output "federated_identity_credential_resource_ids" {
  description = "Resource IDs of the federated identity credentials, by credential name."
  value       = module.user_assigned_identity.federated_identity_credential_resource_ids
}

output "github_variables" {
  description = "The values `azure/login` takes, for the repository's variables `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID`."
  value = {
    AZURE_CLIENT_ID       = module.user_assigned_identity.client_id
    AZURE_TENANT_ID       = module.user_assigned_identity.tenant_id
    AZURE_SUBSCRIPTION_ID = data.azapi_client_config.current.subscription_id
  }
}

output "resource_id" {
  description = "Resource ID of the user-assigned identity."
  value       = module.user_assigned_identity.resource_id
}
