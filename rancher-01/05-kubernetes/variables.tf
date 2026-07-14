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

variable "my_domain" {
  type        = string
  description = "my domain name"
}

variable "rancher_pass" {
  type        = string
  description = "rancher password"
}
