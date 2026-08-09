variable "region" {
  type        = string
  description = "region"
}

variable "bucket" {
  type        = string
  description = "bucket"
}

variable "my_domain" {
  type        = string
  description = "my domain name"
}

variable "rancher" {
  type        = list(string)
  description = "rancher name dns"
}

variable "applications" {
  type        = list(string)
  description = "applications list"
}

variable "rancher_ip" {
  type        = string
  description = "rancher ip"
}

variable "apps_vip" {
  type        = string
  description = "apps vip"
}
