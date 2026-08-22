data "terraform_remote_state" "certificate" {
  backend = "s3"

  config = {
    bucket = var.bucket
    key    = var.key_certificate
    region = var.region
  }
}

data "terraform_remote_state" "rancher" {
  backend = "s3"

  config = {
    bucket = var.bucket
    key    = var.key_rancher
    region = var.region
  }
}

resource "helm_release" "argo_cd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true

  values = [
    "${file("${path.module}/helm-values/argocd.yaml")}"
  ]
}

resource "helm_release" "argocd_appset" {
  name             = "argocd-appset"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true
  values           = ["${file("${path.module}/helm-values/argocd-appset.yaml")}"]

  depends_on = [helm_release.argo_cd]
}

resource "kubernetes_secret_v1" "argocd_cluster_secrets" {
  for_each = data.terraform_remote_state.rancher.outputs.rancher2_downstream_clusters

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
      bearerToken = data.terraform_remote_state.rancher.outputs.rancher_token_argocd
      tlsClientConfig = {
        insecure = false
      }
    })
  }

  type = "Opaque"

  depends_on = [helm_release.argocd_appset]
}

resource "null_resource" "install_policy" {
  for_each = { for downstream_cluster in data.terraform_remote_state.rancher.outputs.downstream_clusters: downstream_cluster.name => downstream_cluster }

  provisioner "local-exec" {
    command = <<EOF
      KUBECONFIG=~/.kube/${each.value.name} kubectl apply --server-side -f - <<KUBE
apiVersion: "cilium.io/v2alpha1"
kind: CiliumL2AnnouncementPolicy
metadata:
  name: policy1
spec:
  serviceSelector:
    matchLabels:
      color: blue
  nodeSelector:
    matchExpressions:
      - key: node-role.kubernetes.io/control-plane
        operator: DoesNotExist
  externalIPs: true
  loadBalancerIPs: true
KUBE
    EOF
  }
}

resource "local_file" "ippool" {
  for_each = { for downstream_cluster in data.terraform_remote_state.rancher.outputs.downstream_clusters: downstream_cluster.name => downstream_cluster }

  filename = "/tmp/ippool-${each.value.name}.yaml"
  content  = templatefile("${path.module}/manifests/ippool.yaml.tftpl",
    {
      start_ip = each.value.start_cilium_vip
      stop_ip  = each.value.stop_cilium_vip
    }
  )
}

resource "null_resource" "install_ciliuml2announcement" {
  for_each = { for downstream_cluster in data.terraform_remote_state.rancher.outputs.downstream_clusters: downstream_cluster.name => downstream_cluster }

  provisioner "local-exec" {
    command = <<EOF
      KUBECONFIG=~/.kube/${each.value.name} kubectl apply -f /tmp/ippool-${each.value.name}.yaml
    EOF
  }

  depends_on = [null_resource.install_policy, local_file.ippool]
}
