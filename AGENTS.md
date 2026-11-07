# Agent instructions

## Terraform apply policy

**Never run `terraform apply`, `terraform destroy`, `terraform import`, or
`terraform state` mutations automatically.** This applies to every environment,
including `dev`.

The only allowed default flow is:

1. `terraform fmt -check -recursive`
2. `terraform init` (or `terraform init -backend=false`)
3. `terraform validate`
4. `terraform plan`

Run `terraform apply` **only** when the user explicitly asks for it and confirms
the environment, the plan, and the expected changes. If there is any doubt, stop
and ask first.

See `README.md` → "Apply policy — plan and validate only".
