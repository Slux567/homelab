resource "proxmox_vm_qemu" "odin" {

  # -- General settings
  name = "odin"
  desc = "This VM is used to run Docker services for home automation and other tasks. Local only, no public access."
  agent = 1  # Enable QEMU Guest Agent
  target_node = "asgard"  # Target node
  tags = "Docker"
  vmid = 200

  # -- Template settings
  clone = "ubuntu-cloudinit-template"  # <-- Change to the name of the template or VM you want to clone
  full_clone = true  # <-- (Optional) Set to "false" to create a linked clone

  # -- Boot Process
  onboot = true 

  # Startup, shutdown and auto reboot behavior
  startup = ""
  automatic_reboot = false

  # -- Hardware Settings
  qemu_os = "other"
  bios = "seabios"
  cores = 2
  sockets = 1
  cpu_type = "host"
  memory = 8192

  # -- Network Settings
  network {
    id = 0
    bridge = "vmbr0"
    model  = "virtio"
    tag = 30
    firewall = false
  }

  # -- Disk Settings

  scsihw = "virtio-scsi-pci"  # Use VirtIO SCSI controller
  disks {
    ide {
      ide0 {
        cloudinit {
          storage = "external"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          storage = "external"
          size = "200G"
          iothread = true
          replicate = false
        }
      }
    }
  }
  # -- Video Settings
serial {
  id   = 0
  type = "socket"
}
vga {
  type = "serial0"
}

  # -- Cloud Init Settings
  ipconfig0 = "ip=10.30.10.1/16,gw=10.30.0.1"  # <-- Change to your desired IP configuration
  ciuser = var.vm_user  # <-- Change to your desired username
  sshkeys = file(var.public_ssh_key)  # <-- (Optional) Change to your public SSH key
}