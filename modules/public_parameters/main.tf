terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "environment" {
  description = "Environment used in /vestio/<environment>/<ENV_VAR>; optimizer retains a service namespace."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "services" {
  description = "Non-secret environment maps. Backend/frontend share the environment root; other services retain their namespace."
  type        = map(map(string))

  validation {
    condition     = length(setintersection(toset(keys(lookup(var.services, "backend", {}))), toset(keys(lookup(var.services, "frontend", {}))))) == 0
    error_message = "Backend and frontend keys must be distinct because they share one Parameter Store path."
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
    contains(["backend", "frontend"], service) ? "/vestio/${var.environment}" : "/vestio/${var.environment}/${service}"
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
  description = "Backend/frontend share the environment root; optimizer has its own namespace."
  value       = local.paths
}

output "path_arns" {
  description = "Exact path ARNs for scoped GetParametersByPath access."
  value = {
    for service in keys(var.services) : service =>
    "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${local.paths[service]}"
  }
}
