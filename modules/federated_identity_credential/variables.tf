variable "issuer" {
  type        = string
  description = "URL of the external identity provider, for example `https://token.actions.githubusercontent.com`. Up to 600 characters."
  nullable    = false

  validation {
    condition     = length(var.issuer) > 0 && length(var.issuer) <= 600
    error_message = "`issuer` must be 1 to 600 characters."
  }
}

variable "name" {
  type        = string
  description = "Name of the federated identity credential. Changing it replaces the credential."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{2,119}$", var.name))
    error_message = "`name` must be 3 to 120 characters: letters, digits, hyphens and underscores, starting with a letter or digit."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the user-assigned identity that holds the credential."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", var.parent_id))
    error_message = "`parent_id` must be a user-assigned identity resource ID."
  }
}

variable "subject" {
  type        = string
  description = "Identifier of the external workload, for example `repo:<owner>/<repo>:environment:<name>`. It must match the token's `sub` claim exactly (no wildcards). Up to 600 characters."
  nullable    = false

  validation {
    condition     = length(var.subject) > 0 && length(var.subject) <= 600
    error_message = "`subject` must be 1 to 600 characters."
  }
}

variable "audiences" {
  type        = list(string)
  default     = ["api://AzureADTokenExchange"]
  description = "The audience accepted in the external token. Azure takes exactly one, up to 600 characters."
  nullable    = false

  validation {
    condition     = length(var.audiences) == 1 && alltrue([for audience in var.audiences : length(audience) > 0 && length(audience) <= 600])
    error_message = "`audiences` must hold exactly one audience of 1 to 600 characters."
  }
}
