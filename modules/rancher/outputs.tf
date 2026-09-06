output "downstream_clusters" {
  value       = var.downstream_clusters
  description = "names of the downstream clusters created in Rancher"
}

output "downstream_clusters_tokens" {
  value = {
    for k, cluster in rancher2_cluster_v2.downstream_clusters :
    k => cluster.cluster_registration_token[0].node_command
  }
  description = "per-cluster rke2 node registration commands"
  sensitive   = true
}
