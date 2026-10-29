# Default example

A resource group, then a user-assigned identity with one role assignment on it: Managed Identity
Operator for the principal running the example, which lets it assign the identity to resources.

Run it with `scripts/e2e.sh examples/default`: apply, a second plan that must be empty, destroy.
