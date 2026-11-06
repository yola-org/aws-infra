terraform {
  required_version = ">= 1.10.0" # for S3 backend use_lockfile

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
