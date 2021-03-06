resource "azurerm_virtual_network" "main" {
  count               = "${var.enabled}"
  name                = "${var.lidop_name}-${terraform.workspace}-network"
  address_space       = ["172.10.0.0/16"]
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
}

resource "azurerm_subnet" "internal" {
  count                = "${var.enabled}"
  name                 = "${var.lidop_name}-${terraform.workspace}-internal"
  resource_group_name  = "${azurerm_resource_group.main.name}"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  address_prefix       = "172.10.10.0/24"
}

resource "azurerm_network_interface" "master" {
  count                     = "${var.enabled}"
  name                      = "${var.lidop_name}-${terraform.workspace}-master-nic"
  location                  = "${azurerm_resource_group.main.location}"
  resource_group_name       = "${azurerm_resource_group.main.name}"
  network_security_group_id = "${azurerm_network_security_group.nsg.id}"

  ip_configuration {
    name                          = "master_ip_config"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "172.10.10.10"
    public_ip_address_id          = "${azurerm_public_ip.master.id}"
  }
}

resource "azurerm_public_ip" "master" {
  count                   = "${var.enabled}"
  name                    = "${var.lidop_name}-${terraform.workspace}-master-pip"
  location                = "${azurerm_resource_group.main.location}"
  resource_group_name     = "${azurerm_resource_group.main.name}"
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30

  tags = {
    environment = "test"
  }
}

resource "azurerm_network_interface" "worker" {
  count                     = "${var.enabled * var.workers}"
  name                      = "${var.lidop_name}-${terraform.workspace}-worker-nic-${count.index}"
  location                  = "${azurerm_resource_group.main.location}"
  resource_group_name       = "${azurerm_resource_group.main.name}"
  network_security_group_id = "${azurerm_network_security_group.nsg.id}"

  ip_configuration {
    name                          = "worker_ip_config-${count.index}"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "172.10.10.1${count.index + 1}"
    public_ip_address_id          = "${element(azurerm_public_ip.worker.*.id, count.index)}"
  }
}

resource "azurerm_public_ip" "worker" {
  count                   = "${var.enabled * var.workers}"
  name                    = "${var.lidop_name}-${terraform.workspace}-pip-worker-${count.index}"
  location                = "${azurerm_resource_group.main.location}"
  resource_group_name     = "${azurerm_resource_group.main.name}"
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30

  tags = {
    environment = "test"
  }
}

resource "azurerm_network_security_group" "nsg" {
  count               = "${var.enabled}"
  name                = "${var.lidop_name}-${terraform.workspace}-security-group"
  location            = "${var.azure_region}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  security_rule {
    name                       = "HTTPS"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "ssh"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags {
    environment = "${var.lidop_name}-${terraform.workspace}"
  }
}
