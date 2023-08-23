resource "azurerm_resource_group" "CUR_Lin_resourcegroup" {
  count    = length(local.csv_data)
  name     = local.format_csv_data[count.index].resourcegroup
  location = local.csv_data[count.index].location

   provisioner "local-exec" {
    command = "echo Resource Group: ${local.format_csv_data[count.index].resourcegroup} Location: ${local.csv_data[count.index].location}"
  }
}

resource "azurerm_virtual_network" "CUR_Lin_Vnetwork" {
  count            = length(local.csv_data)
  name             = local.csv_data[count.index].virtualNetworkName
  location         = azurerm_resource_group.CUR_Lin_resourcegroup[count.index].location
  resource_group_name = azurerm_resource_group.CUR_Lin_resourcegroup[count.index].name
  address_space    = [local.csv_data[count.index].vnetAddressPrefixes]

  /*depends_on = [
  azurerm_resource_group.CUR_Lin_resourcegroup[count.index]
]*/
}

resource "azurerm_subnet" "CUR_Lin_Subnet" {
  count              = length(local.csv_data)
  name               = local.csv_data[count.index].subnetName
  resource_group_name = azurerm_resource_group.CUR_Lin_resourcegroup[count.index].name
  virtual_network_name = azurerm_virtual_network.CUR_Lin_Vnetwork[count.index].name
  address_prefixes   = [local.csv_data[count.index].snetAddressPrefixes]

  /*depends_on = [
  azurerm_resource_group.CUR_Lin_resourcegroup[count.index],
  azurerm_virtual_network.CUR_Lin_Vnetwork[count.index]
]*/
}

resource "azurerm_network_security_group" "CUR_Lin_NSG" {
  for_each            = local.format_csv_data_map
  name                = each.value.nsgName
  location            = each.value.location
  resource_group_name = azurerm_resource_group.CUR_Lin_resourcegroup[each.key].name


  //name                = local.format_csv_data[count.index].nsgName
 // location            = local.format_csv_data[count.index].location
 // resource_group_name = azurerm_resource_group.CUR_Lin_resourcegroup[count.index].name

  dynamic "security_rule" {
     for_each = each.value.nsg_rules
    //for_each = jsondecode(local.format_csv_data[count.index].nsg_rules)

    content {
      name                       = security_rule.value.rdpRuleName
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.sourcePortRange
      destination_port_range     = security_rule.value.destinationPortRange
      source_address_prefix      = security_rule.value.sourceAddressPrefix
      destination_address_prefix = security_rule.value.destinationAddressPrefix
    }
  }

  /*depends_on = [
    azurerm_resource_group.CUR_Lin_resourcegroup[count.index]
   // azurerm_virtual_network.CUR_Lin_Vnetwork[count.index]
  ]*/
}

resource "azurerm_network_interface" "CUR_Lin_Network_Interface" {
  count             = length(local.csv_data)
  name              = local.csv_data[count.index].nicName
  location          = azurerm_resource_group.CUR_Lin_resourcegroup[count.index].location
  resource_group_name = azurerm_resource_group.CUR_Lin_resourcegroup[count.index].name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.CUR_Lin_Subnet[count.index].id
    private_ip_address_allocation = local.csv_data[count.index].privateIPAllocationMethod
    private_ip_address            = local.csv_data[count.index].privateIPv4Address
  }

  /*depends_on = [
    azurerm_subnet.CUR_Lin_Subnet[count.index],
    azurerm_resource_group.CUR_Lin_resourcegroup[count.index]
  ]*/

}

resource "random_id" "storage_account_id" {
  count      = length(local.csv_data)
  byte_length = 8
  prefix     = "diag"

 /* depends_on = [
  azurerm_resource_group.CUR_Lin_resourcegroup[count.index]
]*/
}

resource "azurerm_storage_account" "storage_account" {
  count                     = length(local.csv_data)
  name                      = "${random_id.storage_account_id[count.index].hex}"
  resource_group_name       = azurerm_resource_group.CUR_Lin_resourcegroup[count.index].name
  location                  = local.csv_data[count.index].location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
}

resource "tls_private_key" "CUR_Lin_ssh" {
  count     = length(local.csv_data)
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_virtual_machine" "CUR_Lin_VM" {
  count                = length(local.csv_data)
  name                 = local.csv_data[count.index].virtualMachineName
  location             = local.csv_data[count.index].location
  resource_group_name  = azurerm_resource_group.CUR_Lin_resourcegroup[count.index].name
  network_interface_ids = [azurerm_network_interface.CUR_Lin_Network_Interface[count.index].id]
  vm_size              = local.csv_data[count.index].virtualMachineSize
  //admin_username      = local.csv_data[count.index].adminUsername
 
    delete_os_disk_on_termination = true
    os_profile {
    computer_name  = local.csv_data[count.index].virtualMachineName
    admin_username = local.csv_data[count.index].adminUsername

   // custom_data = base64encode(local.csv_data[count.index].customData)
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${local.csv_data[count.index].adminUsername}/.ssh/authorized_keys"
      key_data = tls_private_key.CUR_Lin_ssh[count.index].public_key_openssh
    }
  }

   storage_image_reference {
    publisher = local.csv_data[count.index].osImagePublisher
    offer     = local.csv_data[count.index].osOffer
    sku       = local.csv_data[count.index].osSKU
    version   = local.csv_data[count.index].oSVersion
  }

  storage_os_disk {
    name              = local.csv_data[count.index].osDiskName
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = local.csv_data[count.index].osDiskType
  }
/*
  boot_diagnostics {
    enabled     = true
    storage_uri = azurerm_storage_account.storage_account[count.index].primary_blob_endpoint
  }
*/

   /*depends_on = [
    azurerm_network_interface.CUR_Lin_Network_Interface[count.index],
    azurerm_network_security_group.CUR_Lin_NSG
     
  ]*/
  
}