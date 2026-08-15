module "kubernetes" {
  source           = "../../modules/kubernetes"
  region           = var.region
  bucket           = var.bucket
  key_certificate  = var.key_certificate
  key_rancher      = var.key_rancher
  my_domain        = var.my_domain
  start_cilium_vip = "192.168.1.101"
  stop_cilium_vip  = "192.168.1.110"
  argocd_pass      = var.argocd_pass
}
