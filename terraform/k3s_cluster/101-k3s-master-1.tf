resource "proxmox_vm_qemu" "k3s-master-1" {

  # -- Basic VM Info
  name        = "k3s-master-1"
  vmid        = 101
  target_node = "asgard"
  desc        = "This VM is the master node in the Kubernetes cluster."
  
  # -- Cloud Init Settings
  ciuser      = var.vm_user
  sshkeys     = file(var.public_ssh_key)
  nameserver  = "1.1.1.1 1.0.0.1"
  ipconfig0   = "ip=192.168.1.10/16,gw=192.168.1.254"
  skip_ipv6   = true
  cicustom    = "vendor=local:snippets/qemu-guest-agent.yml"
  ciupgrade   = true

  # -- Compute Resources
  cpu {
      cores = 1
      sockets = 1
      type = "host"
  }
  memory = 8192

  # -- Template Settings / Operating System
  clone      = "ubuntu-24.04-cloudinit"
  full_clone = true

  # -- Network Settings
  network {
    id       = 0
    bridge   = "vmbr0"
    model    = "virtio"
  }

  # -- Disk Settings
  scsihw = "virtio-scsi-pci"
  disks {
    ide {
      ide0 {
        cloudinit {
          storage = "storage"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          storage   = "storage"
          size      = "50G"
          iothread  = true
          replicate = false
        }
      }
    }
  }

  # -- Boot and Runtime Behavior
  agent             = 1
  boot              = "order=scsi0"
  onboot            = true
  vm_state          = "running"
  startup           = ""
  automatic_reboot  = true

  # -- Misc Hardware Settings
  qemu_os = "other"
  bios    = "seabios"

  # -- Video & Serial
  serial {
    id   = 0
    type = "socket"
  }

  vga {
    type = "serial0"
  }
}
