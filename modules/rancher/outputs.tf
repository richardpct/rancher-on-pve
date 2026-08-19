output "downstream_clusters" {
  value = var.downstream_clusters
}

output "rancher2_downstream_clusters" {
  value = rancher2_cluster_v2.downstream_clusters
}

output "downstream_clusters_tokens" {
  value = {
    for k, cluster in rancher2_cluster_v2.downstream_clusters :
    k => cluster.cluster_registration_token[0].node_command
  }
}

output "rancher_token_argocd" {
  value = rancher2_token.argocd.token
}
