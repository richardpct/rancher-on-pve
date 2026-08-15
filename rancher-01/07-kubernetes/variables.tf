variable "region" {
  type        = string
  description = "region"
}

variable "bucket" {
  type        = string
  description = "bucket"
}

variable "key_kubernetes" {
  type        = string
  description = "bucket kubernetes key"
}

variable "key_certificate" {
  type        = string
  description = "bucket certificate key"
}

variable "key_rancher" {
  type        = string
  description = "bucket rancher key"
}

variable "my_domain" {
  type        = string
  description = "my domain name"
}

variable "argocd_pass" {
  type        = string
  description = "argocd password"
}
