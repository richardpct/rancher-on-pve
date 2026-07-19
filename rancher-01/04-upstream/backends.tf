terraform {
  backend "s3" {
    bucket = var.bucket
    key    = var.key_upstream
    region = var.region
  }
}
