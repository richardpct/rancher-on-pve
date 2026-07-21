terraform {
  backend "s3" {
    bucket = var.bucket
    key    = var.key_downstream
    region = var.region
  }
}
