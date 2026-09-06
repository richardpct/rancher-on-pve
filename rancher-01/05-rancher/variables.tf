variable "region" {
  type        = string
  description = "region"
}

variable "bucket" {
  type        = string
  description = "bucket"
}

variable "key_rancher" {
  type        = string
  description = "bucket rancher key"
}

variable "key_certificate" {
  type        = string
  description = "bucket certificate key"
}

variable "key_dns" {
  type        = string
  description = "bucket dns key"
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
  description = "rancher admin password"
  sensitive   = true
}

variable "argocd_pass" {
  type        = string
  description = "argocd admin password"
  sensitive   = true
}
