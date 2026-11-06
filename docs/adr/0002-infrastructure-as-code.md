# 0002 — Infrastructure as code with Terraform

**Context.** The first version of the platform was created by hand in the Azure portal: more than 50 screens, easy to get wrong and impossible to repeat exactly.

**Decision.** Describe every resource in [infra/main.tf](../../infra/main.tf) (azurerm + databricks providers). Terraform authenticates with a dedicated service principal whose credentials live in a local `.env` file (never in Git). The state file is local and ignored by Git because it contains secrets; the provider lock file is committed.

**Consequences.**
- `terraform apply` builds the platform in minutes; `terraform destroy` removes it, so nothing keeps billing after the demo.
- The manual resources were deleted and rebuilt from code to prove the configuration is complete.
- Interactive `az login` does not work in WSL with a personal Microsoft account; a service principal is also what CI/CD would use.
