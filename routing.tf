resource "azurerm_route_table" "spoke1" {
  name                = "rt-${var.prefix}-spoke1"
  location            = azurerm_resource_group.spoke1.location
  resource_group_name = azurerm_resource_group.spoke1.name
  tags                = var.tags
}

resource "azurerm_route" "spoke1_default" {
  name                   = "default-to-fw"
  resource_group_name    = azurerm_resource_group.spoke1.name
  route_table_name       = azurerm_route_table.spoke1.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

resource "azurerm_route" "spoke1_to_spoke2" {
  name                   = "to-spoke2"
  resource_group_name    = azurerm_resource_group.spoke1.name
  route_table_name       = azurerm_route_table.spoke1.name
  address_prefix         = "10.2.0.0/16"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "spoke1" {
  subnet_id      = azurerm_subnet.spoke1_workload.id
  route_table_id = azurerm_route_table.spoke1.id
}

resource "azurerm_route_table" "spoke2" {
  name                = "rt-${var.prefix}-spoke2"
  location            = azurerm_resource_group.spoke2.location
  resource_group_name = azurerm_resource_group.spoke2.name
  tags                = var.tags
}

resource "azurerm_route" "spoke2_default" {
  name                   = "default-to-fw"
  resource_group_name    = azurerm_resource_group.spoke2.name
  route_table_name       = azurerm_route_table.spoke2.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

resource "azurerm_route" "spoke2_to_spoke1" {
  name                   = "to-spoke1"
  resource_group_name    = azurerm_resource_group.spoke2.name
  route_table_name       = azurerm_route_table.spoke2.name
  address_prefix         = "10.1.0.0/16"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "spoke2" {
  subnet_id      = azurerm_subnet.spoke2_workload.id
  route_table_id = azurerm_route_table.spoke2.id
}