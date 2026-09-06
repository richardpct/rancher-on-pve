locals {
  ubuntu_mirror        = "http://fr.archive.ubuntu.com/ubuntu/"
  ubuntu_version       = "24.04"
  ubuntu_name          = "noble"
  clone                = "ubuntu-${local.ubuntu_version}-cloudinit"
  master_cores         = 2
  worker_cores         = 2
  master_memory        = 4096
  worker_memory        = 4096
  master_disk          = "30G"
  worker_disk          = "30G"
  storage              = var.is_prod ? "mypool" : "local-lvm"
  k8s_masters_list     = join(" ", [for k8s_master in var.k8s_masters : k8s_master.ip])
  k8s_workers_list     = join(" ", [for k8s_worker in var.k8s_workers : k8s_worker.ip])
  kube_config_upstream = "~/.kube/local"
  cluster_type         = "upstream"
}

variable "region" {
  type        = string
  description = "region"
}

variable "bucket" {
  type        = string
  description = "bucket"
}

variable "nameserver" {
  type        = string
  description = "nameserver"
}

variable "gateway" {
  type        = string
  description = "gateway"
}

variable "public_ssh_key" {
  type        = string
  description = "ssh public key injected into the VMs via cloud-init"
}

variable "pm_api_url" {
  type        = string
  description = "proxmox api url"
}

variable "pm_user" {
  type        = string
  description = "proxmox api user"
}

variable "pm_password" {
  type        = string
  description = "proxmox api password"
  sensitive   = true
}

variable "is_prod" {
  type        = bool
  description = "is this a production environment?"
}

variable "kubernetes_version" {
  type        = string
  description = "kubernetes version"
}

variable "pve_nodes" {
  type = list(object({
    name             = string
    ip               = string
    cloudinit_img_id = number
  }))
}

variable "k8s_masters" {
  type = list(object({
    name        = string
    vmid        = number
    ip          = string
    cidr_prefix = number
    target_node = string
  }))
}

variable "k8s_workers" {
  type = list(object({
    name        = string
    vmid        = number
    ip          = string
    cidr_prefix = number
    target_node = string
  }))
}
