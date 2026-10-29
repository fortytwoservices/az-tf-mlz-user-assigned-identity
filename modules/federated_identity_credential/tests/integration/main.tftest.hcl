# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> terraform test -test-directory=tests/integration
# Proves the submodule works when called alone and that a changed subject, issuer or audience is updated
# in place.

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

run "create" {
  variables {
    name      = "github-main"
    parent_id = run.setup.identity_id
    issuer    = "https://token.actions.githubusercontent.com"
    subject   = "repo:example-org/example-repo:ref:refs/heads/main"
  }

  assert {
    condition     = output.resource_id == "${run.setup.identity_id}/federatedIdentityCredentials/github-main"
    error_message = "The credential should be created under the identity."
  }
}

run "update_subject" {
  variables {
    name      = "github-main"
    parent_id = run.setup.identity_id
    issuer    = "https://token.actions.githubusercontent.com"
    subject   = "repo:example-org/example-repo:environment:production"
  }

  assert {
    condition     = output.resource_id == run.create.resource_id && azapi_resource.this.body.properties.subject == "repo:example-org/example-repo:environment:production"
    error_message = "A new subject should be written to the same credential."
  }
}

run "update_issuer" {
  variables {
    name      = "github-main"
    parent_id = run.setup.identity_id
    issuer    = "https://app.terraform.io"
    subject   = "organization:example-org:project:default:workspace:example:run_phase:plan"
  }

  assert {
    condition     = output.resource_id == run.create.resource_id && azapi_resource.this.body.properties.issuer == "https://app.terraform.io"
    error_message = "A new issuer should be written to the same credential."
  }
}

run "update_audience" {
  variables {
    name      = "github-main"
    parent_id = run.setup.identity_id
    issuer    = "https://app.terraform.io"
    subject   = "organization:example-org:project:default:workspace:example:run_phase:plan"
    audiences = ["api://mlz-example-audience"]
  }

  assert {
    condition     = output.resource_id == run.create.resource_id && azapi_resource.this.body.properties.audiences == tolist(["api://mlz-example-audience"])
    error_message = "A custom audience should be written to the same credential."
  }
}
