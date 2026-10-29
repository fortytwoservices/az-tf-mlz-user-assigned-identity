# az-tf-mlz-user-assigned-identity

A Fortytwo managed landing zone (MLZ) module for one user-assigned managed identity
(`Microsoft.ManagedIdentity/userAssignedIdentities`) and its federated identity credentials, in AzAPI:
the Azure Monitor Agent's identity, identities for customer-managed keys and Key Vault access, and
deployment identities that pipelines sign in as through OpenID Connect (GitHub Actions and others).

- **Federated identity credentials** (`federated_identity_credentials`, keyed by credential name; up to
  20 per identity) trust tokens from an external identity provider by `issuer`, `subject` and one
  audience (`api://AzureADTokenExchange` by default). Azure refuses parallel credential writes under one
  identity, so they are written one at a time (`modules/federated_identity_credential`, which can also be
  called alone with an identity's resource ID). A changed issuer, subject or audience is written in
  place; a renamed credential is replaced. A new credential can take a few minutes to work: until it has
  replicated, sign-ins fail with `AADSTS70021`.
- **The identity's lock and role assignments** through
  [`az-tf-mlz-interfaces`](https://github.com/fortytwoservices/az-tf-mlz-interfaces). The lock also
  covers the credentials, so it is removed around any change to them. `role_assignments` are roles **on
  the identity** (for example Managed Identity Operator for whoever assigns it to resources); roles
  **for** the identity belong to the target resource's module (its `role_assignments`) or to
  [`az-tf-mlz-role-assignment`](https://github.com/fortytwoservices/az-tf-mlz-role-assignment), with
  `principal_id` set to this module's `principal_id` and `principal_type = "ServicePrincipal"`.
- **`isolation_scope`** `None` (Azure's default) or `Regional`, which lets only resources in the
  identity's region use it. No diagnostic settings: identities have none.

```hcl
module "deployment_identity" {
  source = "git::https://github.com/fortytwoservices/az-tf-mlz-user-assigned-identity.git?ref=vX.Y.Z"

  name      = "id-platform-deploy"
  parent_id = azapi_resource.resource_group.id
  location  = "swedencentral"
  federated_identity_credentials = {
    github-production = {
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:<owner>/<repo>:environment:production"
    }
  }
  lock = { kind = "CanNotDelete" }
}
```

Things to know:

- A `ReadOnly` lock blocks updates of the identity itself (tags, isolation scope): remove it first.
  Credentials can be added, changed and removed under either lock kind.
- The pair of `issuer` and `subject` must be unique per identity, and no property takes wildcards.
  Matching subjects by expression (flexible federated identity credentials) is a preview that only
  preview API versions accept, so this module does not offer it yet.
- GitHub's subjects carry the repository's owner and name (`repo:<owner>/<repo>:...`), or, in the
  immutable format that repositories created, renamed or transferred after 2026-07-15 use, also their
  IDs (`repo:<owner>@<owner-id>/<repo>@<repo-id>:...`). Copy the prefix from the repository's OIDC
  settings: a subject that does not match fails the sign-in without saying why.
- Azure does not support federated identity credentials on identities in Malaysia South.

Examples: `default` (an identity with a role assignment on it) and `github_actions` (a deployment
identity with credentials for a repository's environment and its pull requests).
