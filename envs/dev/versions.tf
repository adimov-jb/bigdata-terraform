terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Configuração parcial: o bucket do state é informado no init, ex.:
  #   terraform init -backend-config="bucket=<bucket-do-state>"
  backend "s3" {
    key          = "bigdata/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
