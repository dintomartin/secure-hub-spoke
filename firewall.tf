resource "azurerm_public_ip" "fw" {
  name                = "pip-${var.prefix}-fw"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy" "main" {
  name                = "afwp-${var.prefix}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall" "main" {
  name                = "afw-${var.prefix}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.main.id
  tags                = var.tags

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.fw.id
    public_ip_address_id = azurerm_public_ip.fw.id
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "main" {
  name               = "rcg-${var.prefix}"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 500

  network_rule_collection {
    name     = "net-rules"
    priority = 400
    action   = "Allow"

    rule {
      name                  = "allow-spoke-to-spoke"
      protocols             = ["TCP", "UDP", "ICMP"]
      source_addresses      = ["10.1.0.0/16", "10.2.0.0/16"]
      destination_addresses = ["10.1.0.0/16", "10.2.0.0/16"]
      destination_ports     = ["*"]
    }

    rule {
      name                  = "allow-dns"
      protocols             = ["UDP"]
      source_addresses      = ["10.1.0.0/16", "10.2.0.0/16"]
      destination_addresses = ["*"]
      destination_ports     = ["53"]
    }
  }

  application_rule_collection {
    name     = "app-rules"
    priority = 500
    action   = "Allow"

    rule {
      name = "allow-os-update"
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
      source_addresses  = ["10.1.0.0/16", "10.2.0.0/16"]
      destination_fqdns = ["*.ubuntu.com", "*.windowsupdate.com", "*.microsoft.com", "*.azure.com"]
    }
  }
}