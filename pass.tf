resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_storage_account" "main" {
  name                          = "st${var.prefix}${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.spoke2.name
  location                      = azurerm_resource_group.spoke2.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_mssql_server" "main" {
  name                          = "sql-${var.prefix}-${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.spoke2.name
  location                      = azurerm_resource_group.spoke2.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_username
  administrator_login_password  = var.sql_admin_password
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_mssql_database" "main" {
  name      = "sqldb-${var.prefix}"
  server_id = azurerm_mssql_server.main.id
  sku_name  = "Basic"
  tags      = var.tags
}

resource "azurerm_key_vault" "main" {
  name                          = "kv-${var.prefix}-${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.spoke2.name
  location                      = azurerm_resource_group.spoke2.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 7
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
  tags = var.tags
}