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

variable "key_rancher" {
  type        = string
  description = "bucket rancher key"
}

variable "my_domain" {
  type        = string
  description = "my domain name"
}

variable "start_cilium_vip" {
  type        = string
  description = "start cilium vip"
}

variable "stop_cilium_vip" {
  type        = string
  description = "stop cilium vip"
}

variable "argocd_pass" {
  type        = string
  description = "argocd password"
}
