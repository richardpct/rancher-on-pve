provider "kubernetes" {
  config_path = local.kube_config
}

provider "kubectl" {
  config_path = local.kube_config
}

provider "helm" {
  kubernetes = {
    config_path = local.kube_config
  }
}
