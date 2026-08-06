output "downstream_clusters" {
  value = module.rancher.downstream_clusters
}

output "downstream_clusters_tokens" {
  value     = module.rancher.downstream_clusters_tokens
  sensitive = true
}
