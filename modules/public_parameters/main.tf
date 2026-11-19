terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "environment" {
  description = "Environment used in /DEV/<ENV_VAR> or /PROD/<ENV_VAR>."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "services" {
  description = "Shared non-secret infrastructure values, retained under the backend group for stable resource addresses."
  type        = map(map(string))

  validation {
    condition     = length(setsubtract(toset(keys(var.services)), toset(["backend"]))) == 0
    error_message = "Only the shared infrastructure group (backend) is allowed; inject service-specific configuration directly."
  }

  validation {
    condition = alltrue(flatten([
      for values in values(var.services) : [
        for name in keys(values) : contains([
          "AWS_REGION", "S3_ASSETS_BUCKET", "SQS_IMAGE_OPTIMIZATION_QUEUE_URL",
          "COGNITO_CLIENT_ID", "COGNITO_USER_POOL_ID", "COGNITO_REGION",
          "COGNITO_ISSUER_URI", "COGNITO_JWK_SET_URI",
          "APPSYNC_EVENTS_HTTP_ENDPOINT", "APPSYNC_EVENTS_REGION",
        ], name)
      ]
    ]))
    error_message = "Only shared infrastructure keys belong in Parameter Store; NEXT_* and service-specific settings must be passed directly to the service."
  }

  validation {
    condition = alltrue([
      for values in values(var.services) : length(setintersection(toset(keys(values)), toset([
        "COGNITO_CLIENT_SECRET", "PRIMARY_JDBC_URL", "AWS_ACCESS_KEY_ID",
        "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN",
      ]))) == 0
    ])
    error_message = "Credentials and database connection strings must not be stored as public String parameters."
  }

  validation {
    condition = alltrue(flatten([
      for service, values in var.services : concat(
        [can(regex("^[a-z][a-z0-9-]*$", service))],
        [for name in keys(values) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", name))],
      )
    ]))
    error_message = "Services must be lowercase path segments and keys must be valid environment variable names."
  }
}

variable "secret_environment_names" {
  description = "Additional environment variable names managed as secrets; reject them from public parameters."
  type        = set(string)
  default     = []
}

data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  paths = {
    for service in keys(var.services) : service =>
    "/${upper(var.environment)}"
  }
  parameters = merge([
    for service, values in var.services : {
      for name, value in values : "${service}/${name}" => value
    }
  ]...)
}

resource "aws_ssm_parameter" "this" {
  for_each = local.parameters

  name        = "${local.paths[split("/", each.key)[0]]}/${basename(each.key)}"
  description = "Non-secret ${each.key} runtime configuration managed by Terraform."
  type        = "String"
  tier        = "Standard"
  value       = each.value

  lifecycle {
    precondition {
      condition     = !contains(var.secret_environment_names, basename(each.key))
      error_message = "A Secrets Manager environment variable cannot also be stored as a public String parameter."
    }
  }
}

output "names" {
  description = "Parameter names grouped by service and environment variable."
  value = {
    for service, values in var.services : service => {
      for name in keys(values) : name => aws_ssm_parameter.this["${service}/${name}"].name
    }
  }
}

output "arns" {
  description = "Parameter ARNs grouped by service and environment variable."
  value = {
    for service, values in var.services : service => {
      for name in keys(values) : name => aws_ssm_parameter.this["${service}/${name}"].arn
    }
  }
}

output "paths" {
  description = "Shared infrastructure path, retained under the backend group for compatibility."
  value       = local.paths
}

output "path_arns" {
  description = "Exact path ARNs for scoped GetParametersByPath access."
  value = {
    for service in keys(var.services) : service =>
    "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${local.paths[service]}"
  }
}
