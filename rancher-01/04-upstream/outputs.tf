output "pve_nodes" {
  value = module.upstream.pve_nodes
}

output "k8s_masters_upstream" {
  value = module.upstream.k8s_masters_upstream
}
