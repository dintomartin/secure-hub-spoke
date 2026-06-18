# Phase 6 — Test VMs

**Goal:** create one Linux VM per spoke, each with no public IP, so you have something to validate the design from in Phase 7. Both VMs are written out directly.

File: `compute.tf`.

---

## 6.1 What makes these VMs good test instruments

1. **No public IP.** The NIC has no public IP attached, so the only way in is Bastion — which proves the "zero public IPs on workloads" claim.
2. **They sit in the workload subnet** — the subnet with the Phase 4 route table attached, so every packet they send to the internet or the other spoke is forced through the firewall.

---

## 6.2 Create `compute.tf`

Each VM is a network interface (no public IP) plus the VM itself. Two of each, spelled out.

```hcl
# ===== Spoke 1 test VM (no public IP) =====
resource "azurerm_network_interface" "spoke1" {
  name                = "nic-vm-${var.prefix}-spoke1"
  location            = azurerm_resource_group.spoke1.location
  resource_group_name = azurerm_resource_group.spoke1.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.spoke1_workload.id
    private_ip_address_allocation = "Dynamic"
    # No public_ip_address_id, so no public IP. This is intentional.
  }
}

resource "azurerm_linux_virtual_machine" "spoke1" {
  name                            = "vm-${var.prefix}-spoke1"
  location                        = azurerm_resource_group.spoke1.location
  resource_group_name             = azurerm_resource_group.spoke1.name
  size                            = "Standard_B1s"
  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.spoke1.id]
  tags                            = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# ===== Spoke 2 test VM (no public IP) =====
resource "azurerm_network_interface" "spoke2" {
  name                = "nic-vm-${var.prefix}-spoke2"
  location            = azurerm_resource_group.spoke2.location
  resource_group_name = azurerm_resource_group.spoke2.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.spoke2_workload.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "spoke2" {
  name                            = "vm-${var.prefix}-spoke2"
  location                        = azurerm_resource_group.spoke2.location
  resource_group_name             = azurerm_resource_group.spoke2.name
  size                            = "Standard_B1s"
  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.spoke2.id]
  tags                            = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
```

Notes:
- `Standard_B1s` is a cheap, burstable size — fine for connectivity tests.
- `disable_password_authentication = false` enables password login, which keeps Bastion testing simple. Beyond a lab, use SSH keys (`admin_ssh_key { ... }`) and leave password auth off.
- The Ubuntu 22.04 gen2 image reference is stable. If a region rejects it, list valid references with `az vm image list --publisher Canonical --offer 0001-com-ubuntu-server-jammy --all -o table`.

---

## 6.3 How you'll connect (preview)

No public IP means no direct SSH. In Phase 7 you connect via the portal: open the VM, choose Connect, then Bastion, and enter the username and password from your tfvars. A shell opens in the browser, tunneled through the Bastion host in the hub.

➡️ Continue to **[Phase 7 — Deploy & Validate](phase-7-deploy-validate.md)**.
