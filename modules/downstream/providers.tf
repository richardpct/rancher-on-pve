provider "proxmox" {
  pm_api_url      = var.pm_api_url
  pm_user         = var.pm_user
  pm_password     = var.pm_password
  pm_tls_insecure = true
  pm_parallel     = 10
}

provider "kubernetes" {
#  for_each = var.clusters
  for_each = var.provider_clusters
  alias       = "cluster"
  config_path = "~/.kube/${each.key}"
}
