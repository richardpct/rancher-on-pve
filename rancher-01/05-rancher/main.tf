module "rancher" {
  source              = "../../modules/rancher"
  region              = var.region
  bucket              = var.bucket
  key_certificate     = var.key_certificate
  key_dns             = var.key_dns
  key_upstream        = var.key_upstream
  my_domain           = var.my_domain
  kubernetes_version  = "v1.35.6+rke2r1"
  rancher_pass        = var.rancher_pass
  argocd_pass         = var.argocd_pass
  ceph_cluster_id     = var.ceph_cluster_id
  cephfs_secret       = var.cephfs_secret
  downstream_clusters = ["andromeda", "phoenix"]
}
