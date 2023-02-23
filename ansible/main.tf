#
# variable prefix anlegen
########################################################
variable "prefix" {
  default = "Adriano-Christmann-"
}
#
#Resource Gruppe "rg" anlegen
##########################################################
resource "azurerm_resource_group" "Adriano-christmann_RG" {
  name     = "Terraform_Ressource_Groupe_Adriano_Christmann"
  location = "North Europe"
}
#
#    internes Netzwerk anlegen
####################################################
resource "azurerm_virtual_network" "projektnetwork" {
  name                = "${var.prefix}network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.Adriano-christmann_RG.location
  resource_group_name = azurerm_resource_group.Adriano-christmann_RG.name
}
#
# subnet anlegen
#####################################################
resource "azurerm_subnet" "projektsubnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.Adriano-christmann_RG.name
  virtual_network_name = azurerm_virtual_network.projektnetwork.name
  address_prefixes     = ["10.0.2.0/24"]
}
#
# jenkins öffentliche ip 
#####################################################
resource "azurerm_public_ip" "jenkinspublicip" {
  name                = "${var.prefix}jenkins-ip"
  resource_group_name = azurerm_resource_group.Adriano-christmann_RG.name
  location            = azurerm_resource_group.Adriano-christmann_RG.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Production"
  }
}
#
# webserver öffentliche ip
##############################################################
resource "azurerm_public_ip" "webserverpublicip" {
  name                = "${var.prefix}webserver-ip"
  resource_group_name = azurerm_resource_group.Adriano-christmann_RG.name
  location            = azurerm_resource_group.Adriano-christmann_RG.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Production"
  }
}
#
# jenkins netzwerk interface
#####################################################
resource "azurerm_network_interface" "jenkinsnic" {
  name                = "${var.prefix}jenkins-nic"
  location            = azurerm_resource_group.Adriano-christmann_RG.location
  resource_group_name = azurerm_resource_group.Adriano-christmann_RG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.projektsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jenkinspublicip.id
  }
  depends_on = [azurerm_public_ip.jenkinspublicip
  ]
}
#
# webserver netzwek interface
#################################################
resource "azurerm_network_interface" "webservernic" {
  name                = "${var.prefix}webserver-nic"
  location            = azurerm_resource_group.Adriano-christmann_RG.location
  resource_group_name = azurerm_resource_group.Adriano-christmann_RG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.projektsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.webserverpublicip.id
  }
  depends_on = [azurerm_public_ip.jenkinspublicip
  ]
}
#
# nsg anlegen
#####################################################
resource "azurerm_network_security_group" "Adriano-christmann_RG" {
  name                = "${var.prefix}nsg"
  location            = azurerm_resource_group.Adriano-christmann_RG.location
  resource_group_name = azurerm_resource_group.Adriano-christmann_RG.name
}
#
# firewall regel für ssh
#################################################################
resource "azurerm_network_security_rule" "sshd" {
  name                        = "sshd"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.Adriano-christmann_RG.name
  network_security_group_name = azurerm_network_security_group.Adriano-christmann_RG.name
}
#
# firewall regel für web
##################################################################
resource "azurerm_network_security_rule" "web" {
  name                        = "web"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.Adriano-christmann_RG.name
  network_security_group_name = azurerm_network_security_group.Adriano-christmann_RG.name
}
#
# ausgehenden netzwerk verkehr erlauben
####################################################################
resource "azurerm_network_security_rule" "allout" {
  name                        = "web"
  priority                    = 201
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.Adriano-christmann_RG.name
  network_security_group_name = azurerm_network_security_group.Adriano-christmann_RG.name
}
#
# zuordnung jenkins nic zu nsg
#####################################################
resource "azurerm_network_interface_security_group_association" "jenkinsnsg" {
  network_interface_id      = azurerm_network_interface.jenkinsnic.id
  network_security_group_id = azurerm_network_security_group.Adriano-christmann_RG.id
}
#
# zuordnung  webserver nic zu nsg
#####################################################
resource "azurerm_network_interface_security_group_association" "webservernsg" {
  network_interface_id      = azurerm_network_interface.webservernic.id
  network_security_group_id = azurerm_network_security_group.Adriano-christmann_RG.id
}
#
# jenkins  vm anlegen
##################################################
resource "azurerm_linux_virtual_machine" "jenkins" {
  name                = "${var.prefix}jenkins-vm"
  resource_group_name = azurerm_resource_group.Adriano-christmann_RG.name
  location            = azurerm_resource_group.Adriano-christmann_RG.location
  size                = "Standard_B1s"
  admin_username      = "techstarter"
  network_interface_ids = [
    azurerm_network_interface.jenkinsnic.id,
  ]

  admin_ssh_key {
    username   = "techstarter"
    public_key = file("./sshkey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-LTS-gen2"
    version   = "latest"
  }
}
# 
# webserver vm anlegen
#############################################################
resource "azurerm_linux_virtual_machine" "webserver" {
  name                = "${var.prefix}webserver-vm"
  resource_group_name = azurerm_resource_group.Adriano-christmann_RG.name
  location            = azurerm_resource_group.Adriano-christmann_RG.location
  size                = "Standard_B1s"
  admin_username      = "techstarter"
  network_interface_ids = [
    azurerm_network_interface.webservernic.id,
  ]

  admin_ssh_key {
    username   = "techstarter"
    public_key = file("./sshkey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-LTS-gen2"
    version   = "latest"
  }
}
