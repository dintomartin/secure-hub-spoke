# Phase 5 — PaaS, Private DNS & Private Endpoints

**Goal:** deploy Storage, SQL, and Key Vault with public access disabled, then make them reachable on private IPs via private endpoints, with private DNS so the normal hostnames resolve.

Three parts that must line up: the locked-down service, a private endpoint (a private NIC), and a private DNS zone that points the public hostname at the private IP.

Files: `paas.tf`, `dns.tf`, `private-endpoints.tf`.

---

## 5.1 Create `paas.tf` (services with public access disabled)

All three live in the data spoke (`spoke2`). A `random_string` makes their globally-unique names.

```hcl
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
```

`public_network_access_enabled = false` is the line that satisfies "no public access." Until the private endpoints below exist, the services are unreachable from anywhere — which is expected.

---

## 5.2 Create `dns.tf` (zones and links)

Each PaaS type has a fixed `privatelink` zone. The zones live in the hub, and each one is linked to all three VNets so any spoke or the hub can resolve the endpoints. In the direct approach all nine links are written out.

```hcl
# ===== Private DNS zones =====
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags
}

# ===== blob zone -> hub, spoke1, spoke2 =====
resource "azurerm_private_dns_zone_virtual_network_link" "blob_hub" {
  name                  = "blob-hub"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_spoke1" {
  name                  = "blob-spoke1"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.spoke1.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_spoke2" {
  name                  = "blob-spoke2"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.spoke2.id
  registration_enabled  = false
}

# ===== sql zone -> hub, spoke1, spoke2 =====
resource "azurerm_private_dns_zone_virtual_network_link" "sql_hub" {
  name                  = "sql-hub"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_spoke1" {
  name                  = "sql-spoke1"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.spoke1.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_spoke2" {
  name                  = "sql-spoke2"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.spoke2.id
  registration_enabled  = false
}

# ===== vault zone -> hub, spoke1, spoke2 =====
resource "azurerm_private_dns_zone_virtual_network_link" "vault_hub" {
  name                  = "vault-hub"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.vault.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "vault_spoke1" {
  name                  = "vault-spoke1"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.vault.name
  virtual_network_id    = azurerm_virtual_network.spoke1.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "vault_spoke2" {
  name                  = "vault-spoke2"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.vault.name
  virtual_network_id    = azurerm_virtual_network.spoke2.id
  registration_enabled  = false
}
```

Yes, that is nine link blocks. The direct approach trades brevity for transparency: you can see every zone-to-VNet link spelled out, which makes a wrong or missing link obvious.

---

## 5.3 Create `private-endpoints.tf`

Each endpoint is a private NIC connected to one PaaS service. The `private_dns_zone_group` block is what auto-writes the DNS A record so the public hostname resolves to the private IP — forget it and connections fail.

```hcl
resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${var.prefix}-blob"
  location            = azurerm_resource_group.spoke2.location
  resource_group_name = azurerm_resource_group.spoke2.name
  subnet_id           = azurerm_subnet.spoke2_pe.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-blob"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-blob"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

resource "azurerm_private_endpoint" "sql" {
  name                = "pe-${var.prefix}-sql"
  location            = azurerm_resource_group.spoke2.location
  resource_group_name = azurerm_resource_group.spoke2.name
  subnet_id           = azurerm_subnet.spoke2_pe.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-sql"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
}

resource "azurerm_private_endpoint" "vault" {
  name                = "pe-${var.prefix}-kv"
  location            = azurerm_resource_group.spoke2.location
  resource_group_name = azurerm_resource_group.spoke2.name
  subnet_id           = azurerm_subnet.spoke2_pe.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-kv"
    private_dns_zone_ids = [azurerm_private_dns_zone.vault.id]
  }
}
```

**The `subresource_names` value must be exact**, or the endpoint will not attach:

| Service        | subresource | matching zone                     |
| -------------- | ----------- | --------------------------------- |
| Storage (blob) | blob        | privatelink.blob.core.windows.net |
| Azure SQL      | sqlServer   | privatelink.database.windows.net  |
| Key Vault      | vault       | privatelink.vaultcore.azure.net   |

---

## 5.4 A gotcha worth knowing

Once public access is off, you cannot reach these services from your laptop either — including Terraform's data-plane operations (like writing a Key Vault secret) if Terraform runs outside the VNet. For this lab (Terraform only manages the resources, not their contents) that is fine. If you later manage secrets or blobs, run Terraform from a VM inside the VNet or temporarily allow-list your IP.

➡️ Continue to **[Phase 6 — Test VMs](phase-6-test-vms.md)**.
