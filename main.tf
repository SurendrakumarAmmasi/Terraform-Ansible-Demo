terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.84.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = "551d4f9d-a651-4011-a550-f4cdcb4f653a"
}

#resource group
resource "azurerm_resource_group" "tf-ans-demo-rg" {
  name     = "tf-ans-demo-rg"
  location = "Central India"
  
  tags = {
    createdby   = "suren"
    environment = "NPRD"
  }
}

#virtual network
resource "azurerm_virtual_network" "tf-ans-demo-vnet" {
  name = "tf-ans-demo-vnet"
  resource_group_name = azurerm_resource_group.tf-ans-demo-rg.name
  location = azurerm_resource_group.tf-ans-demo-rg.location
  address_space = ["10.1.1.0/24"]
  
  tags = {
    createdby   = "suren"
    environment = "NPRD"
  }
}

# subnet1
resource "azurerm_subnet" "tf-ans-demo-subnet1" {
  name                 = "tf-ans-demo-subnet1"
  resource_group_name  = azurerm_resource_group.tf-ans-demo-rg.name
  virtual_network_name = azurerm_virtual_network.tf-ans-demo-vnet.name
  address_prefixes     = ["10.1.1.0/24"]

}

# security group 
resource "azurerm_network_security_group" "tf-ans-demo-sg" {
  name                = "tf-ans-demo-sg"
  location            = azurerm_resource_group.tf-ans-demo-rg.location
  resource_group_name = azurerm_resource_group.tf-ans-demo-rg.name

  tags = {
    createdby   = "suren"
    environment = "NPRD"
  }
}

# security rule
resource "azurerm_network_security_rule" "tf-ans-demo-rule" {
  name                        = "tf-ans-demo-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "49.249.8.118/32"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.tf-ans-demo-rg.name
  network_security_group_name = azurerm_network_security_group.tf-ans-demo-sg.name
}

#security rule association
resource "azurerm_subnet_network_security_group_association" "tf-ans-demo-sg-associate" {
  subnet_id                 = azurerm_subnet.tf-ans-demo-subnet1.id
  network_security_group_id = azurerm_network_security_group.tf-ans-demo-sg.id
}

#public IP
resource "azurerm_public_ip" "tf-ans-demo-pub-ip" {
  for_each = var.vm_map

  name                = "${each.value.name}-pub-ip"
  resource_group_name = azurerm_resource_group.tf-ans-demo-rg.name
  location            = azurerm_resource_group.tf-ans-demo-rg.location
  allocation_method   = "Dynamic"

  tags = {
    createdby   = "suren"
    environment = "NPRD"
  }
}

#network interface card
resource "azurerm_network_interface" "tf-ans-demo-nic" {
  for_each = var.vm_map

  name                = "${each.value.name}-nic"
  location            = azurerm_resource_group.tf-ans-demo-rg.location
  resource_group_name = azurerm_resource_group.tf-ans-demo-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.tf-ans-demo-subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tf-ans-demo-pub-ip[each.key].id

  }
  

  tags = {
    createdby   = "suren"
    environment = "NPRD"
  }
}

#virtual machine

resource "azurerm_linux_virtual_machine" "tf-ans-demo-vm" {
  for_each = var.vm_map

  name                = each.value.name
  resource_group_name = azurerm_resource_group.tf-ans-demo-rg.name
  location            = azurerm_resource_group.tf-ans-demo-rg.location

  size                  = each.value.size
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.tf-ans-demo-nic[each.key].id]

  

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/azurekey.pub")
  }


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  #custom data
  custom_data = base64encode(file("cloud-init.yaml"))


  tags = {
    createdby   = "suren"
    environment = "NPRD"

  }
}

resource "null_resource" "run_python_script" {
  depends_on = [azurerm_linux_virtual_machine.tf-ans-demo-vm]
  
  provisioner "local-exec" {
    command = "python3 ${path.module}/inventory.py > ${path.module}/inventory.json"
  }
  triggers = {
    always_run = "${timestamp()}"
  }
}



