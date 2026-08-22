module "rancher" {
  source              = "../../modules/rancher"
  region              = var.region
  bucket              = var.bucket
  key_certificate     = var.key_certificate
  key_upstream        = var.key_upstream
  my_domain           = var.my_domain
  rancher_pass        = var.rancher_pass
  argocd_pass         = var.argocd_pass
  downstream_clusters = [
    { name = "andromeda", start_cilium_vip = "192.168.1.101", stop_cilium_vip = "192.168.1.110"},
    { name = "phoenix",   start_cilium_vip = "192.168.1.111", stop_cilium_vip = "192.168.1.120"},
  ]
}
