# Secure Hub-Spoke Network on Azure (Terraform)

A production-style **hub-and-spoke** network on Microsoft Azure, provisioned end-to-end with Terraform. The design centralizes shared connectivity and security services in a hub VNet and isolates workloads in spoke VNets, with **all egress and inter-spoke traffic forced through Azure Firewall**, **PaaS services exposed only through private endpoints (no public access)**, and **administrative access exclusively through Azure Bastion (no public IPs on workload VMs)**.

(guide/architecture.png)

\---

## Overview

This repository deploys a complete secure landing-zone-style network in Azure using a **direct, flat Terraform layout** (every resource declared explicitly — no modules). It is built to demonstrate the networking and security patterns that matter most in real environments: traffic inspection, network segmentation, private connectivity to PaaS, and private DNS resolution.

The topology consists of one hub VNet and two spoke VNets:

* **Hub VNet (`10.0.0.0/16`)** — hosts the shared services: Azure Firewall, Azure Bastion, and a VPN Gateway.
* **Spoke 1 — app (`10.1.0.0/16`)** — a workload VNet for application-tier resources.
* **Spoke 2 — data (`10.2.0.0/16`)** — a workload VNet hosting the PaaS services and their private endpoints.

Spokes are peered to the hub only (never to each other); all spoke-to-spoke and outbound traffic is routed through the firewall via user-defined routes.

\---

## Step-by-step guide

A full, phase-by-phase walkthrough of how this environment is built — with the reasoning behind each resource, not just the code — lives in the [`guide/`](guide/) folder. Start there to reproduce the project yourself or to understand the design in depth.

The guide is split into sequential phases:

* **Phase 0** — Prerequisites and setup
* **Phase 1** — Resource groups and networks
* **Phase 2** — Azure Firewall
* **Phase 3** — Bastion and VPN Gateway
* **Phase 4** — Peering and routing
* **Phase 5** — PaaS, private DNS, and private endpoints
* **Phase 6** — Test VMs
* **Phase 7** — Deploy and validate

\---

## What this project provisions

|Area|Resources|
|-|-|
|**Networking**|1 hub VNet + 2 spoke VNets, with subnets (firewall, bastion, gateway, per-spoke workload and private-endpoint subnets)|
|**Connectivity**|4 VNet peerings (hub ⇄ each spoke) with gateway transit enabled|
|**Routing**|Per-spoke route tables (UDRs) sending `0.0.0.0/0` and the other spoke's range to the firewall|
|**Security and inspection**|Azure Firewall + Firewall Policy with network and application rule collections|
|**Admin access**|Azure Bastion (browser-based RDP/SSH; no public IPs on VMs)|
|**Hybrid connectivity**|VPN Gateway (route-based, `VpnGw1AZ`), shared with both spokes via gateway transit|
|**PaaS (locked down)**|Storage Account, Azure SQL (server + database), Key Vault — all with public network access disabled|
|**Private connectivity**|3 private endpoints (blob, sqlServer, vault) in the data spoke|
|**Name resolution**|3 private DNS zones (`privatelink.\*`) linked to all VNets, with auto-registered A records|
|**Validation**|2 Linux test VMs (one per spoke), no public IPs, reachable only via Bastion|

\---

## Key security properties

1. **No public IPs on workload VMs.** The only administrative path is Azure Bastion.
2. **No public access to PaaS.** Storage, SQL, and Key Vault have `public\_network\_access\_enabled = false`; they are reachable only through private endpoints on private IPs.
3. **All egress is inspected.** A default route (`0.0.0.0/0`) on each spoke sends internet-bound traffic to the firewall, which allows only an explicit set of FQDNs (deny-by-default).
4. **Inter-spoke traffic is inspected.** Spokes are not peered to each other; traffic between them is forced up to the firewall and controlled by an explicit network rule.
5. **Private DNS resolution.** PaaS hostnames resolve to private endpoint IPs from inside the VNets, and to (blocked) public endpoints from outside.

\---

## Tech stack

* **Terraform** `>= 1.5`
* **Provider:** `hashicorp/azurerm \~> 4.0` (plus `hashicorp/random` for unique PaaS names)
* **Cloud:** Microsoft Azure
* **Region:** Central India (an availability-zone-enabled region, required by the current AZ VPN Gateway SKUs)
* **Auth:** Azure CLI session (`az login`)

\---

## Repository structure

```
.
├── providers.tf            # provider + version pins
├── variables.tf            # inputs (subscription, region, prefix, credentials, tags)
├── terraform.tfvars        # local values + secrets (gitignored)
├── main.tf                 # resource groups
├── network.tf              # hub + spoke VNets and subnets
├── firewall.tf             # public IP, policy, firewall, rule collection group
├── bastion.tf              # public IP + bastion host
├── vpn.tf                  # public IP (zone-redundant) + VPN gateway
├── peering.tf              # 4 VNet peerings (gateway transit enabled)
├── routing.tf              # route tables, routes, subnet associations
├── paas.tf                 # storage, SQL, Key Vault (public access disabled)
├── dns.tf                  # 3 private DNS zones + VNet links
├── private-endpoints.tf    # 3 private endpoints
├── compute.tf              # 2 test VMs (no public IP)
├── outputs.tf              # firewall IP, VM IPs, PaaS hostnames, etc.
├── docs/
│   └── architecture.png
└── guide/                  # detailed phase-by-phase walkthrough (Phases 0-7)
```

\---

## Usage

> Prerequisites: an Azure subscription with sufficient rights (Owner, or Contributor + User Access Administrator), Terraform `>= 1.5`, and Azure CLI.

```bash
az login
az account set --subscription "<subscription-id>"

# Provide your values in terraform.tfvars (subscription\_id, passwords, etc.)
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

The VPN Gateway is the slowest resource to provision (roughly 20–45 minutes); the full apply takes about that long. Key outputs (firewall private IP, test VM IPs, PaaS hostnames) are printed on completion.

\---

## Validation

The deployment was verified against the design's security claims:

* **Inter-spoke traffic passes through the firewall** — a `traceroute` from the spoke 1 VM to the spoke 2 VM shows the firewall (in the hub firewall subnet) as the first hop, not a direct path.
* **Outbound internet is filtered** — allowed FQDNs succeed while non-allowed destinations are dropped by the firewall.
* **Private endpoints resolve to private IPs** — `nslookup` of the storage, SQL, and Key Vault hostnames from inside a spoke returns private (`10.x`) addresses via the private DNS zones.
* **Public access is disabled** — the PaaS services are reachable from inside the VNet but not from outside.
* **Bastion-only admin** — the workload VMs have no public IP; access is solely through Bastion.

\---

## Notable design decisions

* **Direct (flat) Terraform.** Every resource is declared explicitly rather than abstracted into modules, making the configuration easy to read and map one-to-one against a `terraform plan`. The tradeoff is some repetition (the two spokes are near-identical blocks).
* **AZ-supported VPN Gateway SKU.** The gateway uses `VpnGw1AZ` with a zone-redundant public IP, in line with Azure's move away from the non-AZ `VpnGw1–5` SKUs. This is why the project deploys to an availability-zone-enabled region (Central India).
* **Centralized private DNS.** The `privatelink.\*` zones live in the hub resource group and are linked to all VNets, so any spoke or the hub can resolve private endpoints — the standard enterprise pattern.
* **Firewall as the single chokepoint.** Routing (UDRs), peering settings (`allow\_forwarded\_traffic`), and firewall rules are configured together so that egress and inter-spoke traffic are both inspected.

\---

## Possible enhancements

* Send Azure Firewall and NSG flow logs to Log Analytics and build a monitoring workbook.
* Add NSGs per subnet for defense in depth alongside the route tables.
* Upgrade to Azure Firewall Premium for TLS inspection and IDPS.
* Add a Point-to-Site or Site-to-Site VPN connection so the gateway carries real traffic.
* Refactor the spokes into a reusable module (with `for\_each`) once the topology grows.
* Add a CI/CD pipeline (e.g. GitHub Actions) running `fmt`, `validate`, and `plan` with remote state and OIDC authentication.

\---

## Cost \& teardown

Azure Firewall and the VPN Gateway are billed hourly and are the most expensive components. This is a lab environment — tear it down when finished:

```bash
terraform destroy
```

