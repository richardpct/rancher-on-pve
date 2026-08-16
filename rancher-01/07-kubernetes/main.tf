module "kubernetes" {
  source          = "../../modules/kubernetes"
  region          = var.region
  bucket          = var.bucket
  key_certificate = var.key_certificate
  key_rancher     = var.key_rancher
  my_domain       = var.my_domain
  argocd_pass     = var.argocd_pass
}
