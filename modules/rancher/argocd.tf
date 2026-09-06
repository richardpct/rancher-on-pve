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

resource "rancher2_token" "argocd" {
  description = "token for ArgoCD to manage downstream clusters"

  depends_on = [rancher2_setting.agent_tls_mode]
}

resource "kubernetes_secret_v1" "argocd_cluster_secrets" {
  for_each = rancher2_cluster_v2.downstream_clusters

  metadata {
    name      = "argocd-cluster-${each.value.name}"
    namespace = "argocd"

    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      "env"                            = "downstream"
    }
  }

  data = {
    name   = each.value.name
    server = "https://rancher.${var.my_domain}/k8s/clusters/${each.value.cluster_v1_id}"

    config = jsonencode({
      bearerToken = rancher2_token.argocd.token
      tlsClientConfig = {
        insecure = false
      }
    })
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace_v1.argocd, rancher2_token.argocd]
}

resource "helm_release" "argo_cd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true

  values = [
    templatefile("${path.module}/helm-values/argocd.yaml.tftpl",
      {
        domain           = var.my_domain
        argocd_pass_hash = bcrypt(var.argocd_pass)
      }
    )
  ]

  depends_on = [kubernetes_secret_v1.argocd_cluster_secrets]
}

resource "helm_release" "argocd_appset" {
  name             = "argocd-appset"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true

  values = [
    templatefile("${path.module}/helm-values/argocd-appset.yaml.tftpl",
      {
        domain = var.my_domain
      }
    )
  ]

  depends_on = [helm_release.argo_cd]
}
