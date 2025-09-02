variable "proxmox_api_url" {
  type = string
}
variable "proxmox_token_id" {
  type = string
}
variable "proxmox_token_secret" {
  type      = string
  sensitive = true
}

variable "public_ssh_key" {
  type      = string
  sensitive = true
}

variable "vm_user" {
  type      = string
}