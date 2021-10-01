variable "mysql_user_password" {
  type    = string
  default = "openboxes"
  sensitive = true
}

variable "azure_managed_image_name" {
  type    = string
  default = "OpenBoxes-ubuntu-18-04"
}

variable "resource_group" {
  type    = string
  default = "OpenBoxesImageGroup"
}

source "azure-arm" "ob-ubuntu-18-04" {
  # current auth is through az cli -> az login
  use_azure_cli_auth = true

  managed_image_resource_group_name = var.resource_group
  managed_image_name = var.azure_managed_image_name

  os_type = "Linux"
  image_publisher = "Canonical"
  image_offer = "UbuntuServer"
  image_sku = "18.04-LTS"

  location = "East US"
  vm_size = "Standard_B2s"
}

build {
  sources = ["source.azure-arm.ob-ubuntu-18-04"]

  provisioner "shell" {
    script = "./setup-ob.sh"
    environment_vars = [
      "MYSQL_USER_PASSWORD=${var.mysql_user_password}", 
      ]

  }
}
