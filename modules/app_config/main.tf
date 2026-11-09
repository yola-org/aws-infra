locals {
  # One merged view: container env-var name => unprefixed Secrets Manager key.
  # var.secret_keys covers secrets created by Terraform; var.external_secrets
  # covers secrets that already exist in Secrets Manager.
  all_secrets = merge(var.secret_keys, var.external_secrets)

  # Environment-variable name => fully-prefixed Secrets Manager secret name.
  secret_names = {
    for env_name, key in local.all_secrets : env_name => "${var.secret_name_prefix}${key}"
  }

  # Secrets not created by Terraform, looked up by name. The lookup is also the
  # existence check: plan fails if a referenced secret is missing.
  external_keys = toset(values(var.external_secrets))

  # ARNs for secrets created by this configuration.
  managed_secret_arns = var.cognito_secret_arns

  all_secret_arns = merge(
    local.managed_secret_arns,
    { for key, s in data.aws_secretsmanager_secret.external : key => s.arn },
  )

  # Same allowlist, expressed as ARNs for IAM policies.
  secret_read_arns = [for key in values(local.all_secrets) : local.all_secret_arns[key]]
}

data "aws_secretsmanager_secret" "external" {
  for_each = local.external_keys
  name     = "${var.secret_name_prefix}${each.key}"
}

check "no_duplicate_env_names" {
  assert {
    condition     = length(setintersection(keys(var.secret_keys), keys(var.external_secrets))) == 0
    error_message = "An environment variable cannot be both Terraform-managed and external."
  }
}

check "secret_keys_have_arns" {
  assert {
    condition = alltrue([
      for key in values(local.all_secrets) : contains(keys(local.all_secret_arns), key)
    ])
    error_message = "Every secret_keys or external_secrets value must resolve to a Cognito ARN or an existing Secrets Manager secret."
  }
}

removed {
  from = aws_secretsmanager_secret.primary_jdbc_url

  lifecycle {
    destroy = false
  }
}
