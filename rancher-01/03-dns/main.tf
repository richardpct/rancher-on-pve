module "dns" {
  source       = "../../modules/dns"
  region       = var.region
  bucket       = var.bucket
  my_domain    = var.my_domain
  applications = [
    { name = "rancher",   ip = "192.168.1.41" },
    { name = "argocd",    ip = "192.168.1.41" },
    { name = "andromeda", ip = "192.168.1.101" },
    { name = "phoenix",   ip = "192.168.1.111" }
  ]
}
