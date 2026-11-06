provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "vestio"
      Environment = "prod"
      ManagedBy   = "terraform"
      Repository  = "aws-infra"
    }
  }
}
