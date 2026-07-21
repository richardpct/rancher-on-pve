module "downstream" {
  source         = "../../modules/downstream"
  region         = var.region
  bucket         = var.bucket
  nameserver     = var.nameserver
  gateway        = var.gateway
  public_ssh_key = var.public_ssh_key
  pm_api_url     = "https://192.168.1.21:8006/api2/json"
  pm_user        = var.pm_user
  pm_password    = var.pm_password
  is_prod        = "false"
  pve_nodes = [
    { name = "pve-01", ip = "192.168.1.21", cloudinit_img_id = 9001 },
    { name = "pve-02", ip = "192.168.1.22", cloudinit_img_id = 9002 },
    { name = "pve-03", ip = "192.168.1.23", cloudinit_img_id = 9003 }
  ]
  k8s_masters = [
    { name = "andromeda-master-01", vmid = 102, ip = "192.168.1.32", cidr_prefix = 24, target_node = "pve-02" },
    { name = "phoenix-master-01",   vmid = 103, ip = "192.168.1.33", cidr_prefix = 24, target_node = "pve-03" }
  ]
  k8s_workers = [
    { name = "andromeda-worker-01", vmid = 202, ip = "192.168.1.42", cidr_prefix = 24, target_node = "pve-02" },
    { name = "phoenix-worker-01",   vmid = 203, ip = "192.168.1.43", cidr_prefix = 24, target_node = "pve-03" }
  ]
}
