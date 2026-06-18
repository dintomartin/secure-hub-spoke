# Phase 4 — Peering & Routing

**Goal:** connect the VNets with peering, then force spoke traffic through the firewall with route tables. This is the most important phase conceptually.

The one idea to hold onto: **peering creates reachability; route tables decide the path.** Peering alone does not send traffic through the firewall.

Files: `peering.tf`, `routing.tf`.

By now the firewall (Phase 2) and the gateway (Phase 3) both exist, so nothing here is a forward reference.

---

## 4.1 Create `peering.tf`

A peering is two one-directional links, so each hub-and-spoke pair is two resources. With two spokes that is four resources, all written out.

```hcl
# ===== Hub <-> Spoke 1 =====
resource "azurerm_virtual_network_peering" "hub_to_spoke1" {
  name                         = "hub-to-spoke1"
  resource_group_name          = azurerm_resource_group.hub.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke1_to_hub" {
  name                         = "spoke1-to-hub"
  resource_group_name          = azurerm_resource_group.spoke1.name
  virtual_network_name         = azurerm_virtual_network.spoke1.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true
  depends_on                   = [azurerm_virtual_network_gateway.main]
}

# ===== Hub <-> Spoke 2 =====
resource "azurerm_virtual_network_peering" "hub_to_spoke2" {
  name                         = "hub-to-spoke2"
  resource_group_name          = azurerm_resource_group.hub.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke2_to_hub" {
  name                         = "spoke2-to-hub"
  resource_group_name          = azurerm_resource_group.spoke2.name
  virtual_network_name         = azurerm_virtual_network.spoke2.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true
  depends_on                   = [azurerm_virtual_network_gateway.main]
}
```

**The four flags, demystified** (a classic interview question):

| Flag | Set where | Why |
|------|-----------|-----|
| `allow_virtual_network_access` | both | Lets the two VNets exchange traffic at all. |
| `allow_forwarded_traffic` | both | Lets a VNet accept traffic that originated elsewhere and was forwarded by an appliance. Required for spoke to firewall to spoke. |
| `allow_gateway_transit` | hub side | Hub advertises: you may use my VPN gateway. |
| `use_remote_gateways` | spoke side | Spoke says: I will use the hub's gateway instead of my own. |

`depends_on = [azurerm_virtual_network_gateway.main]` on the two spoke-side peerings solves a chicken-and-egg problem: a spoke can only set `use_remote_gateways = true` after the gateway exists.

> Spokes are peered only to the hub, never to each other. There is no spoke1-to-spoke2 peering anywhere — the only path between spokes runs through the firewall, which the routing below enforces.

---

## 4.2 Create `routing.tf`

Each spoke gets its own route table with two routes, plus an association that puts the table into effect on the workload subnet. Both spokes are written out.

```hcl
# ===== Spoke 1 route table =====
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

# ===== Spoke 2 route table =====
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
```

**What each spoke's routes mean** (spoke 1 shown):
- `default-to-fw` (`0.0.0.0/0`) sends all internet-bound traffic to the firewall.
- `to-spoke2` (`10.2.0.0/16`) sends traffic destined for spoke 2 to the firewall, so it is inspected instead of going directly.

**Three rules to burn into memory:**
1. The next hop is the firewall's **private** IP, with `next_hop_type = "VirtualAppliance"`. Never the public IP.
2. Never add a `0.0.0.0/0` route to the firewall on the `AzureFirewallSubnet` itself — that creates a loop.
3. A route table does nothing until it is associated with a subnet. The association is attached to the **workload** subnet only; the private-endpoints subnet keeps default routing.

Notice each spoke routes to the *other* spoke's range, never its own — intra-spoke traffic stays local on Azure's built-in route, and overriding it would break local traffic.

---

## 4.3 Why Bastion still works

The `0.0.0.0/0` route does not break Bastion. Azure uses longest-prefix-match: the peering creates a system route for the hub range `10.0.0.0/16`, which is more specific than `0.0.0.0/0`, so hub-bound traffic (Bastion) uses the peering directly while internet and inter-spoke traffic goes to the firewall.

➡️ Continue to **[Phase 5 — PaaS, DNS & Private Endpoints](phase-5-paas-private-endpoints.md)**.
