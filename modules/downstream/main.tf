data "terraform_remote_state" "certificate" {
  backend = "s3"

  config = {
    bucket = var.bucket
    key    = var.key_certificate
    region = var.region
  }
}

data "terraform_remote_state" "upstream" {
  backend = "s3"

  config = {
    bucket = var.bucket
    key    = var.key_upstream
    region = var.region
  }
}

data "terraform_remote_state" "rancher" {
  backend = "s3"

  config = {
    bucket = var.bucket
    key    = var.key_rancher
    region = var.region
  }
}

resource "null_resource" "update_images" {
  for_each = { for pve_node in data.terraform_remote_state.upstream.outputs.pve_nodes : pve_node.name => pve_node }

  provisioner "local-exec" {
    command = <<EOF
      set -x

      ssh root@${each.value.ip} << IMG
        cd /root
        [ -d my_isos ] || mkdir my_isos
        cd my_isos
        curl -O https://cloud-images.ubuntu.com/releases/${local.ubuntu_name}/release/SHA256SUMS
        if ! grep ubuntu-${local.ubuntu_version}-server-cloudimg-amd64.img SHA256SUMS | sha256sum -c; then
          curl -O https://cloud-images.ubuntu.com/releases/${local.ubuntu_name}/release/ubuntu-${local.ubuntu_version}-server-cloudimg-amd64.img
          qm destroy ${each.value.cloudinit_img_id} || true
          qm create ${each.value.cloudinit_img_id} --name ubuntu-${local.ubuntu_version}-cloudinit
          qm set ${each.value.cloudinit_img_id} --scsi0 local-lvm:0,import-from=/root/my_isos/ubuntu-${local.ubuntu_version}-server-cloudimg-amd64.img
          qm template ${each.value.cloudinit_img_id}
          while ! qm list | grep ubuntu-${local.ubuntu_version}-cloudinit; do sleep 2; done
        fi
IMG
    EOF
  }
}

resource "null_resource" "ssh_keys_cleanup" {
  provisioner "local-exec" {
    command = <<EOF
      set -x

      for i in ${local.k8s_masters_list}; do
        ssh-keygen -R $i
      done

      for i in ${local.k8s_workers_list}; do
        ssh-keygen -R $i
      done
    EOF
  }
}

resource "local_file" "downstream_master" {
  for_each = data.terraform_remote_state.rancher.outputs.downstream_clusters

  filename = "/tmp/downstream-master-${each.key}.yaml"
  content  = templatefile("${path.module}/cloud-init/downstream-master.yaml.tftpl",
    {
      ubuntu_mirror    = local.ubuntu_mirror,
      registration_cmd = data.terraform_remote_state.rancher.outputs.downstream_clusters_tokens[each.key]
    }
  )
}

resource "null_resource" "deploy_cloud_init_scripts_masters" {
  for_each = { for pve_node in data.terraform_remote_state.upstream.outputs.pve_nodes : pve_node.name => pve_node }

  provisioner "local-exec" {
    command = <<EOF
      set -x

      for cluster in ${local.clusters_list}; do
        scp /tmp/downstream-master-$cluster.yaml root@${each.value.ip}:/var/lib/vz/snippets/
      done
    EOF
  }

  depends_on = [local_file.downstream_master]
}

resource "proxmox_vm_qemu" "k8s_master" {
  for_each = { for k8s_master in var.k8s_masters : k8s_master.name => k8s_master }

  vmid        = each.value.vmid
  name        = each.value.name
  tags        = "rke2-master"
  target_node = each.value.target_node
  agent       = 1
  cpu {
    cores = local.master_cores
  }
  memory           = local.master_memory
  boot             = "order=scsi0"
  clone            = local.clone
  scsihw           = "virtio-scsi-single"
  power_state      = "running"
  automatic_reboot = true

  # Cloud-Init configuration
  cicustom   = "vendor=local:snippets/${local.cluster_type}-master-${each.value.cluster}.yaml" # /var/lib/vz/snippets/
  ciupgrade  = true
  nameserver = var.nameserver
  ipconfig0  = "ip=${each.value.ip}/${each.value.cidr_prefix},gw=${var.gateway}"
  skip_ipv6  = true
  ciuser     = "ubuntu"
  sshkeys    = var.public_ssh_key

  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = local.storage
          size    = local.master_disk
        }
      }
    }
    ide {
      ide1 {
        cloudinit {
          storage = local.storage
        }
      }
    }
  }

  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }

  startup_shutdown {
    order            = -1
    shutdown_timeout = -1
    startup_delay    = -1
  }

  depends_on = [null_resource.update_images, null_resource.deploy_cloud_init_scripts_masters]
}

resource "local_file" "downstream_worker" {
  for_each = data.terraform_remote_state.rancher.outputs.downstream_clusters

  filename = "/tmp/downstream-worker-${each.key}.yaml"
  content  = templatefile("${path.module}/cloud-init/downstream-worker.yaml.tftpl",
    {
      ubuntu_mirror    = local.ubuntu_mirror,
      registration_cmd = data.terraform_remote_state.rancher.outputs.downstream_clusters_tokens[each.key]
    }
  )
}

resource "null_resource" "deploy_cloud_init_scripts_workers" {
  for_each = { for pve_node in data.terraform_remote_state.upstream.outputs.pve_nodes : pve_node.name => pve_node }

  provisioner "local-exec" {
    command = <<EOF
      set -x

      for cluster in ${local.clusters_list}; do
        scp /tmp/downstream-worker-$cluster.yaml root@${each.value.ip}:/var/lib/vz/snippets/
      done
    EOF
  }

  depends_on = [local_file.downstream_worker]
}

resource "proxmox_vm_qemu" "k8s_worker" {
  for_each = { for k8s_worker in var.k8s_workers : k8s_worker.name => k8s_worker }

  vmid        = each.value.vmid
  name        = each.value.name
  tags        = "rke2-worker"
  target_node = each.value.target_node
  agent       = 1
  cpu {
    cores = local.worker_cores
  }
  memory           = local.worker_memory
  boot             = "order=scsi0" # has to be the same as the OS disk of the template
  clone            = local.clone
  scsihw           = "virtio-scsi-single"
  power_state      = "running"
  automatic_reboot = true

  # Cloud-Init configuration
  cicustom   = "vendor=local:snippets/${local.cluster_type}-worker-${each.value.cluster}.yaml" # /var/lib/vz/snippets/
  ciupgrade  = true
  nameserver = var.nameserver
  ipconfig0  = "ip=${each.value.ip}/${each.value.cidr_prefix},gw=${var.gateway}"
  skip_ipv6  = true
  ciuser     = "ubuntu"
  sshkeys    = var.public_ssh_key

  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = local.storage
          size    = local.worker_disk
        }
      }
    }
    ide {
      ide1 {
        cloudinit {
          storage = local.storage
        }
      }
    }
  }

  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }

  startup_shutdown {
    order            = -1
    shutdown_timeout = -1
    startup_delay    = -1
  }

  depends_on = [null_resource.update_images, null_resource.deploy_cloud_init_scripts_workers]
}

resource "null_resource" "wait_kubernetes_ready" {
  for_each = data.terraform_remote_state.rancher.outputs.downstream_clusters

  provisioner "local-exec" {
    command = <<EOF
      while ! KUBECONFIG=~/.kube/${each.key} kubectl cluster-info; do
        sleep 30
      done
    EOF
  }

  depends_on = [proxmox_vm_qemu.k8s_worker]
}

#resource "kubernetes_namespace_v1" "web" {
#  for_each = data.terraform_remote_state.rancher.outputs.downstream_clusters
#
#  provider = kubernetes.cluster[each.key]
#
#  metadata {
#    name = "web"
#  }
#
#  depends_on = [null_resource.wait_kubernetes_ready]
#}

resource "kubernetes_secret_v1" "default_tls_cert" {
  for_each = data.terraform_remote_state.rancher.outputs.downstream_clusters

  provider = kubernetes.cluster[each.key]

  metadata {
    name      = "default-tls-cert"
    namespace = "web"
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = data.terraform_remote_state.certificate.outputs.wildcard_certificate
    "tls.key" = data.terraform_remote_state.certificate.outputs.wildcard_private_key
  }

  #depends_on = [kubernetes_namespace_v1.web]
  depends_on = [proxmox_vm_qemu.k8s_worker]
}
