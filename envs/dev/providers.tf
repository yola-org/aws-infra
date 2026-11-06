provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "vestio"
      Environment = "dev"
      ManagedBy   = "terraform"
      Repository  = "aws-infra"
    }
  }
}
