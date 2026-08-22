locals {
  kube_config_local = "~/.kube/local"
}

variable "region" {
  type        = string
  description = "region"
}

variable "bucket" {
  type        = string
  description = "bucket"
}

variable "key_certificate" {
  type        = string
  description = "bucket certificate key"
}

variable "key_upstream" {
  type        = string
  description = "bucket upstream key"
}

variable "my_domain" {
  type        = string
  description = "my domain name"
}

variable "rancher_pass" {
  type        = string
  description = "rancher password"
}

variable "argocd_pass" {
  type        = string
  description = "argocd password"
}

variable "downstream_clusters" {
  type = list(object({
    name             = string
    start_cilium_vip = string
    stop_cilium_vip  = string
  }))
}
