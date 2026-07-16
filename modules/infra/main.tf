resource "null_resource" "update_images" {
  for_each = { for pve_node in var.pve_nodes : pve_node.name => pve_node }

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

      for i in ${local.k8s_control_planes_list}; do
        ssh-keygen -R $i
      done

      for i in ${local.k8s_workers_list}; do
        ssh-keygen -R $i
      done
    EOF
  }
}

resource "local_file" "local_server" {
  filename = "/tmp/local-server.yaml"
  content = templatefile("${path.module}/cloud-init/local-server.yaml.tftpl",
    {
      ubuntu_mirror = local.ubuntu_mirror
    }
  )
}

resource "local_file" "cluster_server" {
  filename = "/tmp/cluster-server.yaml"
  content = templatefile("${path.module}/cloud-init/cluster-server.yaml.tftpl",
    {
      ubuntu_mirror = local.ubuntu_mirror
    }
  )
}

resource "null_resource" "deploy_cloud_init_scripts_masters" {
  for_each = { for pve_node in var.pve_nodes : pve_node.name => pve_node }

  provisioner "local-exec" {
    command = <<EOF
      set -x

      scp /tmp/local-server.yaml   root@${each.value.ip}:/var/lib/vz/snippets/
      scp /tmp/cluster-server.yaml root@${each.value.ip}:/var/lib/vz/snippets/
    EOF
  }

  depends_on = [local_file.local_server, local_file.cluster_server]
}

resource "proxmox_vm_qemu" "k8s_control_plane" {
  for_each    = { for k8s_control_plane in var.k8s_control_planes : k8s_control_plane.name => k8s_control_plane }
  vmid        = each.value.vmid
  name        = each.value.name
  tags        = "rke2-server"
  target_node = each.value.target_node
  agent       = 1
  cpu {
    cores = local.master_cores
  }
  memory           = local.master_memory
  boot             = "order=scsi0"
  clone            = local.clone
  scsihw           = "virtio-scsi-single"
  vm_state         = "running"
  automatic_reboot = true

  # Cloud-Init configuration
  cicustom   = "vendor=local:snippets/${each.value.cluster_type}-server.yaml" # /var/lib/vz/snippets/
  ciupgrade  = true
  nameserver = var.nameserver
  ipconfig0  = "ip=${each.value.ip}/${each.value.cidr_prefix},gw=${var.gateway}"
  skip_ipv6  = true
  ciuser     = "ubuntu"
  sshkeys    = var.public_ssh_key

  # Most cloud-init images require a serial device for their display
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
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
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

resource "null_resource" "wait_rke2_token_is_generated" {
  provisioner "local-exec" {
    command = <<EOF
      while ! ssh -o StrictHostKeyChecking=accept-new ubuntu@192.168.1.31 'sudo ls /var/lib/rancher/rke2/server/token'; do
        sleep 2
      done
    EOF
  }

  depends_on = [proxmox_vm_qemu.k8s_control_plane]
}

data "external" "get_rke2_token" {
  program = ["bash", "${path.module}/scripts/get_rke2_token.sh"]

  depends_on = [null_resource.wait_rke2_token_is_generated]
}

locals {
  rke2_token = data.external.get_rke2_token.result["token"]
}

resource "local_file" "local_agent" {
  filename = "/tmp/local-agent.yaml"
  content = templatefile("${path.module}/cloud-init/local-agent.yaml.tftpl",
    {
      ubuntu_mirror = local.ubuntu_mirror,
      rancher_token = local.rke2_token
    }
  )

  depends_on = [proxmox_vm_qemu.k8s_control_plane]
}

resource "local_file" "cluster_agent" {
  filename = "/tmp/cluster-agent.yaml"
  content = templatefile("${path.module}/cloud-init/cluster-agent.yaml.tftpl",
    {
      ubuntu_mirror = local.ubuntu_mirror
    }
  )
}

resource "null_resource" "deploy_cloud_init_scripts_workers" {
  for_each = { for pve_node in var.pve_nodes : pve_node.name => pve_node }

  provisioner "local-exec" {
    command = <<EOF
      set -x

      scp /tmp/local-agent.yaml   root@${each.value.ip}:/var/lib/vz/snippets/
      scp /tmp/cluster-agent.yaml root@${each.value.ip}:/var/lib/vz/snippets/
    EOF
  }

  depends_on = [local_file.local_agent]
}

resource "proxmox_vm_qemu" "k8s_worker" {
  for_each    = { for k8s_worker in var.k8s_workers : k8s_worker.name => k8s_worker }
  vmid        = each.value.vmid
  name        = each.value.name
  tags        = "rke2-agent"
  target_node = each.value.target_node
  agent       = 1
  cpu {
    cores = local.worker_cores
  }
  memory           = local.worker_memory
  boot             = "order=scsi0" # has to be the same as the OS disk of the template
  clone            = local.clone
  scsihw           = "virtio-scsi-single"
  vm_state         = "running"
  automatic_reboot = true

  # Cloud-Init configuration
  cicustom   = "vendor=local:snippets/${each.value.cluster_type}-agent.yaml" # /var/lib/vz/snippets/
  ciupgrade  = true
  nameserver = var.nameserver
  ipconfig0  = "ip=${each.value.ip}/${each.value.cidr_prefix},gw=${var.gateway}"
  skip_ipv6  = true
  ciuser     = "ubuntu"
  sshkeys    = var.public_ssh_key

  # Most cloud-init images require a serial device for their display
  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        # We have to specify the disk from our template, else Terraform will think it's not supposed to be there
        disk {
          storage = local.storage
          # The size of the disk should be at least as big as the disk in the template. If it's smaller, the disk will be recreated
          size = local.worker_disk
        }
      }
    }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
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

resource "null_resource" "get_local_kube_config" {
  provisioner "local-exec" {
    command = <<EOF
      set -x

      while ! ssh -o StrictHostKeyChecking=accept-new ubuntu@192.168.1.31 'ls /etc/rancher/rke2/rke2.yaml'; do
        sleep 10
      done

      ssh -o StrictHostKeyChecking=accept-new ubuntu@192.168.1.31 'sudo cat /etc/rancher/rke2/rke2.yaml' > ~/.kube/local
      gsed -i 's/127.0.0.1/192.168.1.31/g' ~/.kube/local
      chmod 600 ~/.kube/local
    EOF
  }

  depends_on = [proxmox_vm_qemu.k8s_control_plane]
}
