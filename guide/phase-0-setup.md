# Phase 0 — Prerequisites & Setup

**Goal:** get your machine ready and create the four foundational files. No Azure resources yet.

Time: about 20 minutes. Cost: $0.

---

## 0.1 Install the tools

| Tool | Why | Check |
|------|-----|-------|
| Azure CLI | Authenticates Terraform to Azure. | `az version` |
| Terraform 1.5+ | The IaC engine. | `terraform version` |
| A code editor | VS Code with the HashiCorp Terraform extension is ideal. | — |

Azure CLI: `https://learn.microsoft.com/cli/azure/install-azure-cli`. Terraform: `https://developer.hashicorp.com/terraform/install`.

---

## 0.2 Log in to Azure

```bash
az login
az account list --output table
az account set --subscription "YOUR_SUBSCRIPTION_ID"
az account show --output table
```

Copy the subscription ID for `terraform.tfvars` below. Terraform reuses your `az login` session — no service principal needed for a personal lab. You need **Owner**, or **Contributor + User Access Administrator**, on the subscription.

---

## 0.3 Create the project folder

```bash
mkdir secure-hub-spoke
cd secure-hub-spoke
```

Everything is flat — no subfolders to create.

---

## 0.4 Two Azure rules to know

**Reserved subnet names.** Three hub subnets must be named exactly like this (case-sensitive); Azure attaches the service by name:

| Service | Subnet name | Minimum size |
|---------|-------------|--------------|
| Azure Firewall | `AzureFirewallSubnet` | /26 |
| Azure Bastion | `AzureBastionSubnet` | /26 |
| VPN Gateway | `GatewaySubnet` | /27 |

**Address plan** (no overlaps):

| Network | CIDR | Subnets |
|---------|------|---------|
| Hub | 10.0.0.0/16 | Firewall /26, Bastion /26, Gateway /27 |
| Spoke 1 (app) | 10.1.0.0/16 | workload /24, private-endpoints /24 |
| Spoke 2 (data) | 10.2.0.0/16 | workload /24, private-endpoints /24 |

In the direct approach these CIDRs are written straight into the resources, so there is no address-space variable to manage.

---

## 0.5 Create `providers.tf`

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

provider "random" {}

data "azurerm_client_config" "current" {}
```

The `random` provider gives globally-unique names to the PaaS services later. The `data` block fetches your tenant ID for Key Vault.

---

## 0.6 Create `variables.tf`

In the direct approach we parameterize only what truly varies (subscription, region, names, secrets). Everything structural — CIDRs, SKUs, subnet names — is hardcoded in the resources for clarity.

```hcl
variable "subscription_id" {
  type        = string
  description = "Target Azure subscription ID."
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "prefix" {
  type        = string
  default     = "shs"
  description = "Short name prefix for all resources."
}

variable "vm_admin_username" {
  type    = string
  default = "azureuser"
}

variable "vm_admin_password" {
  type        = string
  sensitive   = true
  description = "Test VM password. 12-72 chars, 3 of 4 complexity categories."
}

variable "sql_admin_login" {
  type    = string
  default = "sqladmin"
}

variable "sql_admin_password" {
  type      = string
  sensitive = true
}

variable "tags" {
  type = map(string)
  default = {
    project = "secure-hub-spoke"
    env     = "lab"
  }
}
```

---

## 0.7 Create `terraform.tfvars` and `.gitignore`

`terraform.tfvars` (your real values — never commit it):

```hcl
subscription_id    = "00000000-0000-0000-0000-000000000000"
location           = "eastus"
prefix             = "shs"

vm_admin_username  = "azureuser"
vm_admin_password  = "REPLACE-Me-With-A-Strong-Pass-123"

sql_admin_login    = "sqladmin"
sql_admin_password = "REPLACE-Me-With-A-Strong-Pass-456"
```

> Password rules: 12-72 characters, at least 3 of: lowercase, uppercase, digit, special character.

`.gitignore`:

```gitignore
*.tfstate
*.tfstate.*
.terraform/
crash.log
terraform.tfvars
*.auto.tfvars
```

---

## 0.8 Initialize

```bash
terraform init
```

This downloads the providers. We run `validate` and `apply` at the end (Phase 7), once all the files exist.

➡️ Continue to **[Phase 1 — Resource Groups & Networks](phase-1-networks.md)**.
