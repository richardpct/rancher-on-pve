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

#resource "helm_release" "argo_cd" {
#  name             = "argo-cd"
#  repository       = "https://argoproj.github.io/argo-helm"
#  chart            = "argo-cd"
#  namespace        = "argocd"
#  create_namespace = true
#  force_update     = true
#
#  values = [
#    "${file("${path.module}/helm-values/argocd.yaml")}"
#  ]
#}
#
#resource "helm_release" "argocd_infra" {
#  name             = "argocd-infra"
#  repository       = "https://argoproj.github.io/argo-helm"
#  chart            = "argocd-apps"
#  namespace        = "argocd"
#  create_namespace = true
#  force_update     = true
#
#  values = [
#    templatefile("${path.module}/helm-values/argocd-infra.yaml.tftpl",
#      {
#        ceph_cluster_id = var.ceph_cluster_id
#      }
#    )
#  ]
#
#  depends_on = [helm_release.argo_cd]
#}

resource "null_resource" "install_policy" {
  for_each = toset(data.terraform_remote_state.rancher.outputs.downstream_clusters)

  provisioner "local-exec" {
    command = <<EOF
      KUBECONFIG=~/.kube/${each.key} kubectl apply --server-side -f - <<KUBE
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
  filename = "/tmp/ippool.yaml"
  content = templatefile("${path.module}/manifests/ippool.yaml.tftpl",
    {
      start_ip = var.start_cilium_vip
      stop_ip  = var.stop_cilium_vip
    }
  )
}

resource "null_resource" "install_ciliuml2announcement" {
  for_each = toset(data.terraform_remote_state.rancher.outputs.downstream_clusters)

  provisioner "local-exec" {
    command = <<EOF
      KUBECONFIG=~/.kube/${each.key} kubectl apply -f /tmp/ippool.yaml
    EOF
  }

  depends_on = [null_resource.install_policy, local_file.ippool]
}
