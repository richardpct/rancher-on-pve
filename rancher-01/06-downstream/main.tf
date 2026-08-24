module "downstream" {
  source            = "../../modules/downstream"
  region            = var.region
  bucket            = var.bucket
  key_certificate   = var.key_certificate
  key_upstream      = var.key_upstream
  key_rancher       = var.key_rancher
  nameserver        = var.nameserver
  gateway           = var.gateway
  public_ssh_key    = var.public_ssh_key
  pm_api_url        = "https://192.168.1.21:8006/api2/json"
  pm_user           = var.pm_user
  pm_password       = var.pm_password
  provider_clusters = ["andromeda", "phoenix"]
  clusters          = ["andromeda", "phoenix"]
  is_prod           = "false"
  k8s_masters = [
    { name = "andromeda-master-01", vmid = 102, ip = "192.168.1.32", cidr_prefix = 24, target_node = "pve-01", cluster = "andromeda" },
    { name = "andromeda-master-02", vmid = 103, ip = "192.168.1.33", cidr_prefix = 24, target_node = "pve-02", cluster = "andromeda" },
    { name = "andromeda-master-03", vmid = 104, ip = "192.168.1.34", cidr_prefix = 24, target_node = "pve-03", cluster = "andromeda" },
    { name = "phoenix-master-01",   vmid = 105, ip = "192.168.1.35", cidr_prefix = 24, target_node = "pve-01", cluster = "phoenix" },
    { name = "phoenix-master-02",   vmid = 106, ip = "192.168.1.36", cidr_prefix = 24, target_node = "pve-02", cluster = "phoenix" },
    { name = "phoenix-master-03",   vmid = 107, ip = "192.168.1.37", cidr_prefix = 24, target_node = "pve-03", cluster = "phoenix" }
  ]
  k8s_workers = [
    { name = "andromeda-worker-01", vmid = 202, ip = "192.168.1.42", cidr_prefix = 24, target_node = "pve-01", cluster = "andromeda" },
    { name = "andromeda-worker-02", vmid = 203, ip = "192.168.1.43", cidr_prefix = 24, target_node = "pve-02", cluster = "andromeda" },
    { name = "andromeda-worker-03", vmid = 204, ip = "192.168.1.44", cidr_prefix = 24, target_node = "pve-03", cluster = "andromeda" },
    { name = "phoenix-worker-01",   vmid = 205, ip = "192.168.1.45", cidr_prefix = 24, target_node = "pve-01", cluster = "phoenix" },
    { name = "phoenix-worker-02",   vmid = 206, ip = "192.168.1.46", cidr_prefix = 24, target_node = "pve-02", cluster = "phoenix" },
    { name = "phoenix-worker-03",   vmid = 207, ip = "192.168.1.47", cidr_prefix = 24, target_node = "pve-03", cluster = "phoenix" }
  ]
}
