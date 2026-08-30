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

variable "dns_record" {
  type = map(string)
}
