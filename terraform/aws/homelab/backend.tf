terraform {
  backend "s3" {
    bucket       = "sugoi-terraform-state-2026"
    key          = "homelab/terraform.tfstate"
    region       = "us-east-2"
    profile      = "lab-admin"
    encrypt      = true
    use_lockfile = true
  }
}
