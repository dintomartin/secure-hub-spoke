# Phase 2 — Azure Firewall

**Goal:** create the firewall, its policy, and the rules — directly, in one file. The firewall is the appliance the spoke route tables (Phase 4) will point at, which is why it comes before routing.

File: `firewall.tf`.

---

## 2.1 How the firewall is structured

Four resources, created in order by their references:
1. a **public IP** (the firewall needs a Standard static IP),
2. a **firewall policy** (holds the rules),
3. the **firewall** itself (placed in `AzureFirewallSubnet`, attached to the policy),
4. a **rule collection group** (the actual rules).

Two rule types appear:
- **Network rules** (Layer 3/4 — IP and port): inter-spoke traffic and DNS.
- **Application rules** (Layer 7 — FQDN): controlled outbound internet.

Everything not explicitly allowed is denied by the firewall's implicit deny.

---

## 2.2 Create `firewall.tf`

```hcl
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

  # Layer 3/4: inter-spoke traffic and DNS.
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

  # Layer 7: controlled outbound internet by FQDN.
  application_rule_collection {
    name     = "app-rules"
    priority = 500
    action   = "Allow"

    rule {
      name = "allow-os-updates"
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
```

---

## 2.3 What the rules do

- `allow-spoke-to-spoke` lets spoke 1 reach spoke 2 — but only because Phase 4's route table sends that traffic to the firewall first. The rule and the route are a pair; either alone does nothing useful.
- `allow-dns` lets the spokes do DNS lookups (needed for the private-endpoint resolution test later).
- `allow-os-updates` lets the test VMs reach package mirrors so `apt update` works. Anything not in the FQDN list is blocked — which you will prove in Phase 7.
- Priorities: lower numbers are evaluated first, and the first match wins.

The spoke CIDRs (`10.1.0.0/16`, `10.2.0.0/16`) are written directly into the rules. With only two spokes this is perfectly readable; if you add a spoke, add its CIDR to these three lists.

---

## 2.4 The output you'll reuse

You don't need a separate output for it, but remember this expression — Phase 4 uses it as the route next hop:

```
azurerm_firewall.main.ip_configuration[0].private_ip_address
```

That is the firewall's **private** IP. Routes always point here, never at the public IP.

> Cost note: the firewall bills hourly while it exists. To level up later, change `sku_tier` to `Premium` for TLS inspection and IDPS.

➡️ Continue to **[Phase 3 — Bastion & VPN Gateway](phase-3-bastion-vpn.md)**.
