module "rancher" {
  source              = "../../modules/rancher"
  region              = var.region
  bucket              = var.bucket
  key_certificate     = var.key_certificate
  key_upstream        = var.key_upstream
  my_domain           = var.my_domain
  rancher_pass        = var.rancher_pass
  downstream_clusters = ["andromeda", "phoenix"]
}
