# Create a resource group
resource "azurerm_resource_group" "example_rg" {
    name                    = "${var.resource_prefix}-RG"
    location                = var.node_location
}

# Locate the existing custom image
data "azurerm_image" "AnsibleLinux" {
  name                = "AnsibleImage"
  resource_group_name = "Test"
}

# Locate the existing custom image
data "azurerm_image" "Linux" {
  name                = "LinuxImage"
  resource_group_name = "Test"
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "example_vnet" {
    name                = "${var.resource_prefix}-vnet"
    resource_group_name = azurerm_resource_group.example_rg.name
    location            = var.node_location
    address_space       = ["10.0.0.0/16"]
}

# Create a subnets within the virtual network
resource "azurerm_subnet" "example_subnet" {
    name                    = "${var.resource_prefix}-subnet"
    resource_group_name     = azurerm_resource_group.example_rg.name
    virtual_network_name    = azurerm_virtual_network.example_vnet.name
    address_prefixes        = ["10.0.2.0/24"]
}

# Create Linux Public IP
resource "azurerm_public_ip" "example_public_ip" {
    count                   = var.node_count
    name                    = "${var.resource_prefix}-${format("%02d", count.index)}-PublicIP"
    #name                   = "${var.resource_prefix}-PublicIP"
    location                = azurerm_resource_group.example_rg.location
    resource_group_name     = azurerm_resource_group.example_rg.name
    allocation_method = var.Environment == "Test" ? "Static" : "Dynamic"

    tags = {
        environment = "Test"
    }
}
# Create Network Interface
resource "azurerm_network_interface" "example_nic" {
    count               = var.node_count
    #name               = "${var.resource_prefix}-NIC"
    name                = "${var.resource_prefix}-${format("%02d", count.index)}-NIC"
    location            = azurerm_resource_group.example_rg.location
    resource_group_name = azurerm_resource_group.example_rg.name
    
    ip_configuration {
        name = "internal"
        subnet_id = azurerm_subnet.example_subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id = element(azurerm_public_ip.example_public_ip.*.id, count.index)
        #public_ip_address_id = azurerm_public_ip.example_public_ip.id
        #public_ip_address_id = azurerm_public_ip.example_public_ip.id
    }
}

# Creating resource NSG
resource "azurerm_network_security_group" "example_nsg" {
    name = "${var.resource_prefix}-NSG"
    location = azurerm_resource_group.example_rg.location
    resource_group_name = azurerm_resource_group.example_rg.name
    # Security rule can also be defined with resource azurerm_network_security_rule, here just defining it inline.
    security_rule {
        name = "Inbound"
        priority = 100
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "*"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }
    tags = {
        environment = "Test"
    }
}

# Subnet and NSG association
resource "azurerm_subnet_network_security_group_association" "example_subnet_nsg_association" {
    subnet_id                   = azurerm_subnet.example_subnet.id
    network_security_group_id   = azurerm_network_security_group.example_nsg.id
}



# Virtual Machine Creation — Linux
resource "azurerm_linux_virtual_machine" "example_linux_vm" {
    # name        = "${var.resource_prefix}-${format("%02d", count.index)}"
    name = "${var.resource_prefix}-LinuxVM"
    source_image_id = data.azurerm_image.Linux.id
    
    location = azurerm_resource_group.example_rg.location
    resource_group_name = azurerm_resource_group.example_rg.name
    size                = "Standard_DS2_v2"
    admin_username      = "surendra"
    network_interface_ids = [
        azurerm_network_interface.example_nic.00.id
        ]

    admin_ssh_key {
        username   = "surendra"
        public_key = file("./.ssh/surendraPub.pem")
    }

    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

}



# Virtual Machine Creation — AnsibleLinux
resource "azurerm_linux_virtual_machine" "example_AnsibleLinux_vm" {
    
    name = "${var.resource_prefix}-AnsibleLinuxVM"
    source_image_id = data.azurerm_image.AnsibleLinux.id
    location = azurerm_resource_group.example_rg.location
    resource_group_name = azurerm_resource_group.example_rg.name
    size                = "Standard_DS2_v2"
    admin_username      = "surendra"
    network_interface_ids = [
        azurerm_network_interface.example_nic.01.id
        ]

    admin_ssh_key {
        username   = "surendra"
        public_key = file("./.ssh/surendraPub.pem")
    }

    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    # connecting to Ansible Server
  connection {
      
      host              = "${azurerm_public_ip.example_public_ip.1.ip_address}"
      user              = "surendra"
      type              = "ssh"
      private_key       = "${file("./.ssh/surendra.pem")}"
      timeout           = "10m"
    }

    # saving Linux server public Ip in Local dir
    provisioner "local-exec" {
        command     = "echo ${azurerm_public_ip.example_public_ip.0.ip_address} > publicIp.txt"
    }

    # copy the publicIp file to ansible server(file used as ansible hosts)
    provisioner "file" {
        source      = "./publicIp.txt"
        destination = "/tmp/hosts"
    }

    # copy the private key to ansible server (used for remote login on linux server)
    provisioner "file" {
        source      = "./.ssh/surendra.pem"
        destination = "~/.ssh/surendra.pem"
    }

    # copy the ansible palybook file from local to ansible server
    provisioner "file" {    
        source      = "./playbook.yml"
        destination = "/tmp/playbook.yml"
    }

    # copy the shell script file(generates the rsa public and private key)
    provisioner "file" {    
        source      = "./code.sh"
        destination = "/tmp/code.sh"
    }    

    # remote execution and remote(ansible server)-remote(linux server)  connection
    # and finally running the playbook
    provisioner "remote-exec" {
        inline = [
          "sudo chmod 400 ~/.ssh/surendra.pem",
          "sudo chmod 777 /tmp/code.sh",
          "sh /tmp/code.sh",
          "cat ~/.ssh/id_rsa.pub | ssh -i ~/.ssh/surendra.pem -o StrictHostKeyChecking=no surendra@${azurerm_public_ip.example_public_ip.0.ip_address} 'cat >> ~/.ssh/authorized_keys'",
          "ansible-playbook -i /tmp/hosts /tmp/playbook.yml",
        ]
    }
    # priority
    depends_on = [
        azurerm_linux_virtual_machine.example_linux_vm
    ]

}
