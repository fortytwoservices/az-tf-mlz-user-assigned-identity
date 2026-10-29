# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> terraform test -test-directory=tests/integration
# Proves what mocks cannot: credentials written in parallel are serialised, survive an update of the
# identity, and are added, changed and removed in one apply under a CanNotDelete and a ReadOnly lock;
# a locked identity is replaced; the lock is removed before everything else on destroy.

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

run "create" {
  variables {
    name      = "id-mlz-uai-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    federated_identity_credentials = {
      one   = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:environment:one" }
      two   = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:environment:two" }
      three = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:environment:three" }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }

  assert {
    condition     = length(output.federated_identity_credential_resource_ids) == 3
    error_message = "All three credentials should be created."
  }
  assert {
    condition     = can(regex("^[0-9a-f-]{36}$", output.principal_id)) && can(regex("^[0-9a-f-]{36}$", output.client_id)) && can(regex("^[0-9a-f-]{36}$", output.tenant_id))
    error_message = "principal_id, client_id and tenant_id should be read back from Azure."
  }
  assert {
    condition     = startswith(output.lock_resource_id, "${output.resource_id}/providers/Microsoft.Authorization/locks/") && keys(output.role_assignment_resource_ids) == ["reader"]
    error_message = "The lock and the role assignment should be on the identity, and output."
  }
}

run "update_identity" {
  variables {
    name      = "id-mlz-uai-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    federated_identity_credentials = {
      one   = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:environment:one" }
      two   = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:environment:two" }
      three = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:environment:three" }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
    isolation_scope = "Regional"
    tags            = { updated = "true" } # a PUT of the identity without its credentials
  }

  assert {
    condition     = azapi_resource.this.tags == tomap({ updated = "true" }) && output.principal_id == run.create.principal_id
    error_message = "The identity should be updated in place."
  }
}

run "credentials_survive" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    credential_ids = run.update_identity.federated_identity_credential_resource_ids
  }

  assert {
    condition     = output.subjects.two == "repo:example-org/example-repo:environment:two" && length(output.subjects) == 3
    error_message = "The credentials should still exist after the identity was updated."
  }
}

run "isolation_scope_set_in_azure" {
  module {
    source = "./tests/integration/read_identity"
  }

  variables {
    identity_id = run.update_identity.resource_id
  }

  assert {
    condition     = output.isolation_scope == "Regional"
    error_message = "Azure should report the Regional isolation scope set by update_identity."
  }
}

run "change_credentials_under_lock" {
  # Under the CanNotDelete lock, in one apply: `three` removed, `two` changed in place, `four` added. The
  # lock is removed and created again around the changes. The scope goes back to Azure's default, which
  # must reach Azure.
  variables {
    name      = "id-mlz-uai-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    federated_identity_credentials = {
      one  = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:environment:one" }
      two  = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:environment:two-updated" }
      four = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:pull_request" }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }

  assert {
    condition     = keys(output.federated_identity_credential_resource_ids) == ["four", "one", "two"] && output.federated_identity_credential_resource_ids["two"] == run.create.federated_identity_credential_resource_ids["two"]
    error_message = "`three` should be gone, `four` added and `two` updated in place."
  }
  assert {
    condition     = output.lock_resource_id != null
    error_message = "The lock should be back."
  }
}

run "credentials_changed_in_azure" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    credential_ids = run.change_credentials_under_lock.federated_identity_credential_resource_ids
  }

  assert {
    condition     = output.subjects["two"] == "repo:example-org/example-repo:environment:two-updated" && output.subjects["four"] == "repo:example-org/example-repo:pull_request" && length(output.subjects) == 3
    error_message = "Azure should report the changed and the added credential."
  }
}

run "isolation_scope_reset_in_azure" {
  module {
    source = "./tests/integration/read_identity"
  }

  variables {
    identity_id = run.change_credentials_under_lock.resource_id
  }

  assert {
    condition     = output.isolation_scope == "None"
    error_message = "Azure should report the default isolation scope again once isolation_scope is no longer set."
  }
}

run "readonly_lock" {
  variables {
    name      = "id-mlz-uai-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    federated_identity_credentials = {
      one  = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:environment:one" }
      two  = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:environment:two-updated" }
      four = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:pull_request" }
    }
    lock = { kind = "ReadOnly" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }
}

run "change_credentials_under_readonly_lock" {
  # A ReadOnly lock blocks credential writes too, updates in place included: each credential's
  # lock_dependency changes with its body, so the lock is removed and created again around them. In
  # one apply: `four` removed, `one` changed in place, `five` added.
  variables {
    name      = "id-mlz-uai-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    federated_identity_credentials = {
      one  = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:environment:one-updated" }
      two  = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:environment:two-updated" }
      five = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:ref:refs/heads/main" }
    }
    lock = { kind = "ReadOnly" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }

  assert {
    condition     = keys(output.federated_identity_credential_resource_ids) == ["five", "one", "two"] && output.federated_identity_credential_resource_ids["one"] == run.create.federated_identity_credential_resource_ids["one"]
    error_message = "`four` should be gone, `five` added and `one` updated in place."
  }
  assert {
    condition     = output.lock_resource_id != null
    error_message = "The lock should be back."
  }
}

run "credentials_changed_under_readonly_lock_in_azure" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    credential_ids = run.change_credentials_under_readonly_lock.federated_identity_credential_resource_ids
  }

  assert {
    condition     = output.subjects["one"] == "repo:example-org/example-repo:environment:one-updated" && output.subjects["five"] == "repo:example-org/example-repo:ref:refs/heads/main" && length(output.subjects) == 3
    error_message = "Azure should report the changed and the added credential."
  }
}

run "replace_locked_identity" {
  # A new name replaces the identity. The lock goes first and the pause is replaced with the identity,
  # so the old identity is deleted only after the lock deletion has propagated.
  variables {
    name      = "id-mlz-uai-it-${run.setup.suffix}-renamed"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    federated_identity_credentials = {
      one = { issuer = "https://token.actions.githubusercontent.com", subject = "repo:example-org/example-repo:environment:one" }
    }
    lock = { kind = "CanNotDelete" }
  }

  assert {
    condition     = output.name == "id-mlz-uai-it-${run.setup.suffix}-renamed" && output.principal_id != run.create.principal_id && startswith(output.lock_resource_id, "${output.resource_id}/providers/Microsoft.Authorization/locks/")
    error_message = "The identity should be replaced (a new principal) and locked again."
  }
}
