provider "kubernetes" {
  config_path = local.kube_config_local
}

provider "kubectl" {
  config_path = local.kube_config_local
}

provider "helm" {
  kubernetes = {
    config_path = local.kube_config_local
  }
}

provider "rancher2" {
  api_url   = "https://rancher.${var.my_domain}"
  bootstrap = true
}
