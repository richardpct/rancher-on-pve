terraform {
  backend "s3" {
    bucket = var.bucket
    key    = var.key_rancher
    region = var.region
  }
}
