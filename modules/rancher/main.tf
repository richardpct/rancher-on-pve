data "terraform_remote_state" "certificate" {
  backend = "s3"

  config = {
    bucket = var.bucket
    key    = var.key_certificate
    region = var.region
  }
}

data "terraform_remote_state" "upstream" {
  backend = "s3"

  config = {
    bucket = var.bucket
    key    = var.key_upstream
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

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [null_resource.wait_kubernetes_ready]
}

resource "kubernetes_secret_v1" "tls_argocd_ingress" {
  metadata {
    name      = "tls-argocd-ingress"
    namespace = "argocd"
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = data.terraform_remote_state.certificate.outputs.wildcard_certificate
    "tls.key" = data.terraform_remote_state.certificate.outputs.wildcard_private_key
  }

  depends_on = [kubernetes_namespace_v1.argocd]
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
      value = length(data.terraform_remote_state.upstream.outputs.k8s_masters_upstream)
    }
  ]

  depends_on = [kubernetes_secret_v1.tls_rancher_ingress]
}

resource "null_resource" "wait_rancher_ready" {
  provisioner "local-exec" {
    command = <<EOF
      while ! curl https://rancher.${var.my_domain}/ping; do
        sleep 2
      done
    EOF
  }

  depends_on = [helm_release.rancher]
}

resource "rancher2_bootstrap" "admin" {
  initial_password = var.rancher_pass
  password         = "${var.rancher_pass}${var.rancher_pass}"

  depends_on = [null_resource.wait_rancher_ready]
}

resource "rancher2_setting" "password_min_length" {
  name  = "password-min-length"
  value = "10"

  depends_on = [rancher2_bootstrap.admin]
}

resource "rancher2_bootstrap" "admin_bis" {
  initial_password = "${var.rancher_pass}${var.rancher_pass}"
  password         = var.rancher_pass

  depends_on = [rancher2_setting.password_min_length]
}

resource "rancher2_setting" "agent_tls_mode" {
  name  = "agent-tls-mode"
  value = "system-store"

  depends_on = [rancher2_bootstrap.admin_bis]
}

resource "rancher2_cluster_v2" "downstream_clusters" {
  for_each = { for downstream_cluster in var.downstream_clusters : downstream_cluster.name => downstream_cluster }

  name                  = each.value.name
  kubernetes_version    = "v1.35.6+rke2r1"
  enable_network_policy = false

  rke_config {
    machine_global_config = yamlencode({
      cni                 = "cilium"
      disable-kube-proxy  = true
      etcd-expose-metrics = false
      ingress-controller  = "traefik"
    })

    chart_values = <<EOF
rke2-cilium:
  kubeProxyReplacement: true
  k8sServiceHost: "127.0.0.1"
  k8sServicePort: 6443
  l2announcements:
    enabled: true
EOF
  }

  depends_on = [rancher2_setting.agent_tls_mode]
}

resource "local_sensitive_file" "downstream_kubeconfig" {
  for_each = rancher2_cluster_v2.downstream_clusters

  filename        = pathexpand("~/.kube/${each.key}")
  content         = each.value.kube_config
  file_permission = "0600"

  depends_on = [rancher2_cluster_v2.downstream_clusters]
}
