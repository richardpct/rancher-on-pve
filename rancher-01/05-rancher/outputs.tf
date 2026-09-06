output "downstream_clusters" {
  value       = module.rancher.downstream_clusters
  description = "names of the downstream clusters created in rancher"
}

output "downstream_clusters_tokens" {
  value       = module.rancher.downstream_clusters_tokens
  description = "per-cluster rke2 node registration commands"
  sensitive   = true
}
