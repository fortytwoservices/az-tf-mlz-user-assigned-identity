# GitHub Actions example

A deployment identity for a GitHub repository's workflows, under a `CanNotDelete` lock, with two
federated identity credentials, written one after the other as Azure requires: one for jobs that run in
the `production` environment (`repo:<owner>/<repo>:environment:production`) and one for pull request
runs (`repo:<owner>/<repo>:pull_request`). A workflow signs in with `azure/login` and the values in the
`github_variables` output, with `permissions: id-token: write`.

The identity has no roles yet. Grant them where it deploys, with the target's module (its
`role_assignments`) or `az-tf-mlz-role-assignment`, using its `principal_id` and
`principal_type = "ServicePrincipal"`. Pull request runs come from any branch, so an identity with a pull
request credential, like this one, gets read-only roles (enough for `terraform plan`); write roles go to
a separate identity whose only credential is a protected environment.

Run it with `scripts/e2e.sh examples/github_actions`: apply, a second plan that must be empty, destroy.
