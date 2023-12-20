variable "vm_map" {
  type = map(object({
    name = string
    size = string
  }))
  default = {
    "vm1" = {
      name = "ansible-controller-vm"
      size = "Standard_B2s"
    }
  }
}
