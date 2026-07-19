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
