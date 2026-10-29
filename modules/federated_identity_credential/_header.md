# Federated identity credential

One federated identity credential on a user-assigned identity
(`Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials`). The root module
calls it once per credential; it can also be called alone with the identity's resource ID:

```hcl
source = "git::https://github.com/fortytwoservices/az-tf-mlz-user-assigned-identity.git//modules/federated_identity_credential?ref=vX.Y.Z"
```

Azure rejects parallel writes of credentials under one identity (409 Conflict), so every write locks
the parent identity's ID and credentials are written one at a time. Credentials written from two
Terraform states at once are not serialised against each other. Issuer, subject and audience are
updated in place; a new name replaces the credential.

A caller that locks the identity passes `lock_dependency` in its lock's dependencies: Azure applies the
identity's lock to the credential too, and a `ReadOnly` lock also blocks updating it in place.
