output "downstream_clusters" {
  value     = module.rancher.downstream_clusters
  sensitive = true
}

output "rancher2_downstream_clusters" {
  value     = module.rancher.rancher2_downstream_clusters
  sensitive = true
}

output "downstream_clusters_tokens" {
  value     = module.rancher.downstream_clusters_tokens
  sensitive = true
}

output "rancher_token_argocd" {
  value     = module.rancher.rancher_token_argocd
  sensitive = true
}
