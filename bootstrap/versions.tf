terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = "eu-north-1"

  default_tags {
    tags = {
      project    = "eks-preview-lab"
      managed-by = "terraform"
    }
  }
}