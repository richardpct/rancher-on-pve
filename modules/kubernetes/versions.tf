terraform {
  required_version = ">= 1.12.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.2.0"
    }
  }
}
