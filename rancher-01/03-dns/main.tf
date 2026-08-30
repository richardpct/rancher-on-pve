module "dns" {
  source       = "../../modules/dns"
  region       = var.region
  bucket       = var.bucket
  my_domain    = var.my_domain
  dns_record = {
    rancher   = "192.168.1.41"
    argocd    = "192.168.1.41"
    andromeda = "192.168.1.101"
    phoenix   = "192.168.1.111"
  }
}
