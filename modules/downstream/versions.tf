terraform {
  required_version = ">= 1.12.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc09"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.3.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
  }
}
