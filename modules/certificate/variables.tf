variable "region" {
  type        = string
  description = "AWS region used for the Route53 DNS-01 challenge"
}

variable "my_domain" {
  type        = string
  description = "base domain; a *.<domain> wildcard cert is requested"
}

variable "my_email" {
  type        = string
  description = "contact email registered with the ACME account"
}
