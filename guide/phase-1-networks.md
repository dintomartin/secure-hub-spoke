# Phase 1 — Resource Groups & Networks

**Goal:** create three resource groups and all the virtual networks and subnets — written out directly, one resource at a time.

Files: `main.tf`, `network.tf`.

---

## 1.1 Create `main.tf` (resource groups)

One resource group for the hub and one for each spoke. Each is its own explicit block.

```hcl
resource "azurerm_resource_group" "hub" {
  name     = "rg-${var.prefix}-hub"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "spoke1" {
  name     = "rg-${var.prefix}-spoke1"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "spoke2" {
  name     = "rg-${var.prefix}-spoke2"
  location = var.location
  tags     = var.tags
}
```

`${var.prefix}` just substitutes the prefix (default `shs`), giving `rg-shs-hub`, `rg-shs-spoke1`, `rg-shs-spoke2`.

---

## 1.2 Create `network.tf` (VNets and subnets)

### Hub VNet and its three reserved subnets

```hcl
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.prefix}-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = ["10.0.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "fw" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.0.0/26"]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/26"]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.2.0/27"]
}
```

The subnet **names** must be exactly `AzureFirewallSubnet`, `AzureBastionSubnet`, and `GatewaySubnet` (Phase 0). The hub holds only shared-service subnets — no workloads run here.

Notice each subnet references its VNet through `azurerm_virtual_network.hub.name`. That reference is how Terraform knows to create the VNet first, then the subnets — you never specify ordering by hand.

### Spoke 1 (app)

```hcl
resource "azurerm_virtual_network" "spoke1" {
  name                = "vnet-${var.prefix}-spoke1"
  location            = azurerm_resource_group.spoke1.location
  resource_group_name = azurerm_resource_group.spoke1.name
  address_space       = ["10.1.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "spoke1_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.spoke1.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = ["10.1.0.0/24"]
}

resource "azurerm_subnet" "spoke1_pe" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.spoke1.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = ["10.1.1.0/24"]
}
```

### Spoke 2 (data)

Same shape as spoke 1, with the `10.2.x` range. The data spoke is where the PaaS services and their private endpoints will live (Phase 5).

```hcl
resource "azurerm_virtual_network" "spoke2" {
  name                = "vnet-${var.prefix}-spoke2"
  location            = azurerm_resource_group.spoke2.location
  resource_group_name = azurerm_resource_group.spoke2.name
  address_space       = ["10.2.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "spoke2_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.spoke2.name
  virtual_network_name = azurerm_virtual_network.spoke2.name
  address_prefixes     = ["10.2.0.0/24"]
}

resource "azurerm_subnet" "spoke2_pe" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.spoke2.name
  virtual_network_name = azurerm_virtual_network.spoke2.name
  address_prefixes     = ["10.2.1.0/24"]
}
```

---

## 1.3 The direct pattern in action

Notice spoke 1 and spoke 2 are deliberately two separate, near-identical blocks. That repetition is the price of the direct approach — and the payoff is that there is nothing to decode: each VNet and subnet is right there with its own name and CIDR. To add a `spoke3`, you would copy a spoke block, rename it, and use the `10.3.x` range.

You will reference these resources by their explicit names throughout the rest of the project, for example:
- `azurerm_subnet.fw.id` (the firewall's subnet),
- `azurerm_subnet.spoke1_workload.id` (where spoke 1's VM goes),
- `azurerm_virtual_network.spoke2.id` (for peering).

➡️ Continue to **[Phase 2 — Azure Firewall](phase-2-firewall.md)**.
