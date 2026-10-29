output "client_id" {
  description = "Client (application) ID of the identity."
  value       = module.user_assigned_identity.client_id
}

output "principal_id" {
  description = "Object ID of the identity's service principal."
  value       = module.user_assigned_identity.principal_id
}

output "resource_id" {
  description = "Resource ID of the user-assigned identity."
  value       = module.user_assigned_identity.resource_id
}

output "role_assignment_resource_ids" {
  description = "Resource IDs of the role assignments on the identity, by key."
  value       = module.user_assigned_identity.role_assignment_resource_ids
}
