# Phase 3 — Bastion & VPN Gateway

**Goal:** add the two remaining hub services. Bastion gives admin access with no public IPs on VMs; the VPN gateway provides hybrid connectivity. Both come before peering (Phase 4), because the spoke peerings consume the gateway.

Files: `bastion.tf`, `vpn.tf`.

---

## 3.1 Create `bastion.tf`

Bastion brokers RDP/SSH over TLS from the portal to a VM's private IP, so workload VMs never expose 3389/22 and never need a public IP. It is a public IP plus the host.

```hcl
resource "azurerm_public_ip" "bastion" {
  name                = "pip-${var.prefix}-bastion"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "main" {
  name                = "bas-${var.prefix}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku                 = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
```

Because Bastion sits in the hub and the hub will be peered to both spokes (Phase 4), it can reach VMs in either spoke over the peering — no extra wiring. The `Standard` SKU enables the native client and tunneling; `Basic` works for portal RDP/SSH but lacks those.

---

## 3.2 Create `vpn.tf`

One gateway in the hub serves both spokes through gateway transit (configured on the peerings in Phase 4). A public IP plus the gateway.

```hcl
# Optional + slow (20-45 min). To skip: delete this file and set the two
# gateway-transit flags to false in peering.tf.
resource "azurerm_public_ip" "vpn" {
  name                = "pip-${var.prefix}-vpngw"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"] # required: AZ gateway SKUs need a zone-redundant public IP
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "main" {
  name                = "vpngw-${var.prefix}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1AZ" # AZ SKU now mandatory; non-AZ VpnGw1-5 can no longer be created
  tags                = var.tags

  ip_configuration {
    name                          = "vnetGatewayConfig"
    subnet_id                     = azurerm_subnet.gateway.id
    public_ip_address_id          = azurerm_public_ip.vpn.id
    private_ip_address_allocation = "Dynamic"
  }
}
```

> **AZ SKU is mandatory (Azure change, Nov 2025).** Non-AZ gateway SKUs (`VpnGw1`–`VpnGw5`) can no longer be created — you must use the `AZ` variant (`VpnGw1AZ` here). AZ gateways also require a **zone-redundant Standard public IP**, which is why the public IP above sets `zones = ["1", "2", "3"]`. This works in regions that have three availability zones (for example `eastus`, `westeurope`). If your chosen region lacks zones, deploy the gateway in a region that has them, or use a single-zone value like `zones = ["1"]`.

---

## 3.3 The big caveat: time and cost

> **A VPN Gateway takes 20-45 minutes to provision** and bills hourly. It is the slowest resource in the build.

If you only want the firewall + private-endpoint story, skip it cleanly:
1. Do not create `vpn.tf`.
2. In `peering.tf` (Phase 4), set `allow_gateway_transit = false` on the hub-side peerings and `use_remote_gateways = false` on the spoke-side peerings, and remove the `depends_on` lines.

Everything else still works.

To actually establish a tunnel later you would add `azurerm_local_network_gateway` (the remote side) and `azurerm_virtual_network_gateway_connection` (the IPsec connection). Left out here to keep the lab cheap.

➡️ Continue to **[Phase 4 — Peering & Routing](phase-4-peering-routing.md)**.
