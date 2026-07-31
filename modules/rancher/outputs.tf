output "downstream_clusters_tokens" {
  value = { 
      for k, cluster in rancher2_cluster_v2.downstream_clusters :
      k => cluster.cluster_registration_token[0].node_command
  }
}
