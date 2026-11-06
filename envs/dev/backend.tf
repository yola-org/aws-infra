# Remote state for the dev environment.
# The bucket must exist before `terraform init` — see README "State backend".
terraform {
  backend "s3" {
    bucket       = "vestio-terraform-state"
    key          = "dev/terraform.tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
