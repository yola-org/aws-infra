# Remote state for the prod environment.
# The bucket must exist before `terraform init` — see README "State backend".
terraform {
  backend "s3" {
    bucket       = "vestio-terraform-state-cac1"
    key          = "prod/terraform.tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
