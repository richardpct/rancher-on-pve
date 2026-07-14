module "dns" {
  source       = "../../modules/dns"
  region       = var.region
  bucket       = var.bucket
  my_domain    = var.my_domain
  rancher_ip   = "192.168.1.41"
  applications = ["rancher"]
}
