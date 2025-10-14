resource "proxmox_vm_qemu" "k3s-worker-1" {

  # -- Basic VM Info
  name        = "k3s-worker-1"
  vmid        = 102
  target_node = "asgard"
  desc        = "This VM is used to run local services for home automation and other tasks. Local only, no public access."

  # -- Cloud Init Settings
  ciuser      = var.vm_user
  sshkeys     = file(var.public_ssh_key)
  nameserver  = "1.1.1.1 1.0.0.1"
  ipconfig0   = "ip=192.168.1.20/16,gw=192.168.1.254"
  skip_ipv6   = true
  cicustom    = "vendor=local:snippets/qemu-guest-agent.yml"
  ciupgrade   = true

  # -- Compute Resources
  cpu {
      cores = 4
      sockets = 1
      type = "host"
  }
  memory = 16384

  # -- Template Settings / Operating System
  clone      = "ubuntu-24.04-cloudinit"  # Change to the desired template name
  full_clone = true                  # Optional: false for linked clone

  # -- Network Settings
  network {
    id       = 0
    bridge   = "vmbr0"
    model    = "virtio"
  }

  # -- Disk Settings
  scsihw = "virtio-scsi-pci"  # Use VirtIO SCSI controller
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
          size      = "100G"
          iothread  = true
          replicate = false
        }
      }
    }
  }

  # -- Boot and Runtime Behavior
  agent             = 1                    # Enable QEMU Guest Agent
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
