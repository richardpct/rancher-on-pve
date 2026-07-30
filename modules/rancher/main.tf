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
  password         = var.rancher_pass

  depends_on = [null_resource.wait_rancher_ready]
}

resource "rancher2_setting" "agent_tls_mode" {
  name  = "agent-tls-mode"
  value = "system-store"

  depends_on = [rancher2_bootstrap.admin]
}

resource "rancher2_cluster_v2" "downstream_clusters" {
  for_each              = toset(var.downstream_clusters)
  name                  = each.key
  kubernetes_version    = "v1.35.6+rke2r1"
  enable_network_policy = false
  // There are two builtin PSACT: rancher-privileged and rancher-restricted. You can also create new ones.
  #default_pod_security_admission_configuration_template_name = "rancher-restricted"
  rke_config {
    machine_global_config = yamlencode({
      cni                 = "cilium"
      disable-kube-proxy  = false
      etcd-expose-metrics = false
      ingress-controller  = "traefik"
    })
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
