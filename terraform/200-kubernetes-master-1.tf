resource "proxmox_vm_qemu" "kubernetes-master-1" {

  # -- Basic VM Info
  name        = "kubernetes-master-1"
  vmid        = 200
  target_node = "midgard"
  desc        = "This VM is the master node in the Kubernetes cluster."
  
  # -- Cloud Init Settings
  ciuser      = var.vm_user                  # Change to your desired username
  sshkeys     = file(var.public_ssh_key)     # Optional: change to your public SSH key
  nameserver  = "1.1.1.1 1.0.0.1"
  ipconfig0   = "ip=10.30.65.44/16,gw=10.30.0.1"  # Change IP as needed
  skip_ipv6   = true
  cicustom    = "vendor=local:snippets/qemu-guest-agent.yml"
  ciupgrade   = true

  # -- Compute Resources
  cpu {
      cores = 2
      sockets = 1
      type = "host"
  }
  memory = 8192

  # -- Template Settings / Operating System
  clone      = "ubuntu-24.04-cloudinit"  # Change to the desired template name
  full_clone = true                  # Optional: false for linked clone

  # -- Network Settings
  network {
    id       = 0
    bridge   = "vmbr0"
    model    = "virtio"
    tag      = 30
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
          size      = "50G"
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
