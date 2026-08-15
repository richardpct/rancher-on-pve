provider "helm" {
  kubernetes = {
    config_path = local.kube_config_local
  }
}
