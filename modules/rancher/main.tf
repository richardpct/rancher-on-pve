data "terraform_remote_state" "certificate" {
  backend = "s3"

  config = {
    bucket = var.bucket
    key    = var.key_certificate
    region = var.region
  }
}

resource "null_resource" "wait_kubernetes_ready" {
  provisioner "local-exec" {
    command = <<EOF
      while ! KUBECONFIG=${local.kube_config_local} kubectl cluster-info; do
        sleep 2
      done
    EOF
  }
}

resource "kubernetes_namespace_v1" "cattle_system" {
  metadata {
    name = "cattle-system"
  }

  depends_on = [null_resource.wait_kubernetes_ready]
}

resource "kubernetes_secret_v1" "tls_rancher_ingress" {
  metadata {
    name      = "tls-rancher-ingress"
    namespace = "cattle-system"
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = data.terraform_remote_state.certificate.outputs.wildcard_certificate
    "tls.key" = data.terraform_remote_state.certificate.outputs.wildcard_private_key
  }

  depends_on = [kubernetes_namespace_v1.cattle_system]
}

resource "helm_release" "rancher" {
  name         = "rancher"
  repository   = "https://releases.rancher.com/server-charts/stable"
  chart        = "rancher"
  namespace    = "cattle-system"
  force_update = true

  set = [
    {
      name  = "hostname"
      value = "rancher.${var.my_domain}"
    },
    {
      name  = "bootstrapPassword"
      value = var.rancher_pass
    },
    {
      name  = "ingress.tls.source"
      value = "secret"
    },
    {
      name  = "replicas"
      value = "1"
    }
  ]

  depends_on = [kubernetes_secret_v1.tls_rancher_ingress]
}

resource "null_resource" "configure_rancher" {
  provisioner "local-exec" {
    command = <<EOF
      set -x
      KUBECONFIG=${local.kube_config_local} kubectl -n cattle-system patch setting agent-tls-mode --type=merge -p '{"value":"system-store"}'
    EOF
  }

  depends_on = [helm_release.rancher]
}
