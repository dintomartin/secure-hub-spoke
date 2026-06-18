# Secure Hub-Spoke Networking on Azure (Terraform) — Direct Approach

A do-it-yourself guide that builds a production-style secure hub-spoke network with **plain, flat Terraform** — no modules, no `for_each` loops over spokes. Every resource is written out explicitly, so you can read exactly what gets created and why. The two spokes are spelled out longhand.

![Architecture](docs/architecture.png)

> If the image doesn't show, open `docs/architecture.png` directly.

---

## What you will build

| Component | Purpose |
|-----------|---------|
| **Hub VNet** | Central VNet holding shared services. |
| **Azure Firewall** | Single egress chokepoint. All internet-bound and inter-spoke traffic is forced through it. |
| **Azure Bastion** | Browser RDP/SSH, so no workload VM needs a public IP. |
| **VPN Gateway** | Hybrid connectivity, shared with both spokes via gateway transit. |
| **Spoke VNets (spoke1 = app, spoke2 = data)** | Peered to the hub, never to each other. |
| **Route tables (UDRs)** | Push spoke traffic through the firewall. |
| **Private Endpoints** | Storage, SQL, and Key Vault reachable only on private IPs. |
| **Private DNS zones** | Make the public PaaS hostnames resolve to those private IPs. |
| **Test VMs** | One per spoke, no public IP, used to validate everything. |

The three security properties you will prove at the end:

1. **No workload VM has a public IP** — admin access is exclusively through Bastion.
2. **No PaaS service is reachable from the internet** — public access is disabled on storage, SQL, and Key Vault.
3. **All egress and spoke-to-spoke traffic passes through the firewall** — enforced by route tables.

---

## Why "direct" (and the tradeoff)

This version uses no modules and no loops. Each resource is declared on its own with an explicit name (for example `azurerm_virtual_network.spoke1` and `azurerm_virtual_network.spoke2` are two separate blocks). The benefit: you see every resource plainly, with nothing hidden behind abstraction — ideal for learning and for reading a `plan` output that maps one-to-one to the code.

The tradeoff: some repetition. The two spokes are near-identical blocks, and the private DNS links are written out (9 of them). To add a third spoke you copy a block and change `spoke2` to `spoke3` and the CIDRs. That is fine for a small, readable lab — and it is the most direct way to learn the resources before reaching for modules later.

---

## Flat file structure you will create

```
secure-hub-spoke/
├── providers.tf            (Phase 0)  provider + version pins
├── variables.tf            (Phase 0)  the few inputs we parameterize
├── terraform.tfvars        (Phase 0)  your values + secrets (never committed)
├── .gitignore              (Phase 0)
├── main.tf                 (Phase 1)  resource groups
├── network.tf              (Phase 1)  hub + spoke VNets and subnets
├── firewall.tf             (Phase 2)  public IP, policy, firewall, rules
├── bastion.tf              (Phase 3)  public IP + bastion host
├── vpn.tf                  (Phase 3)  public IP + VPN gateway
├── peering.tf              (Phase 4)  the 4 peering links
├── routing.tf              (Phase 4)  route tables, routes, associations
├── paas.tf                 (Phase 5)  storage / SQL / key vault (public access off)
├── dns.tf                  (Phase 5)  3 private DNS zones + 9 VNet links
├── private-endpoints.tf    (Phase 5)  3 private endpoints
├── compute.tf              (Phase 6)  2 NICs + 2 Linux VMs
└── outputs.tf              (Phase 7)  values used for testing
```

No `modules/` folder. Everything lives at the root.

---

## Build order (no forward references)

The phases are ordered so each one only references resources from earlier phases. You write all the files first, then deploy once in the final phase.

| Phase | Guide | What you create |
|-------|-------|-----------------|
| 0 | [Prerequisites & setup](docs/phase-0-setup.md) | Tools, login, `providers.tf`, `variables.tf`, `terraform.tfvars`, `.gitignore`. |
| 1 | [Resource groups & networks](docs/phase-1-networks.md) | `main.tf`, `network.tf`. |
| 2 | [Azure Firewall](docs/phase-2-firewall.md) | `firewall.tf`. |
| 3 | [Bastion & VPN Gateway](docs/phase-3-bastion-vpn.md) | `bastion.tf`, `vpn.tf`. |
| 4 | [Peering & routing](docs/phase-4-peering-routing.md) | `peering.tf`, `routing.tf`. |
| 5 | [PaaS, DNS & private endpoints](docs/phase-5-paas-private-endpoints.md) | `paas.tf`, `dns.tf`, `private-endpoints.tf`. |
| 6 | [Test VMs](docs/phase-6-test-vms.md) | `compute.tf`. |
| 7 | [Deploy & validate](docs/phase-7-deploy-validate.md) | `outputs.tf`, then apply and run the validation suite. |

---

## Cost & teardown warning

**Azure Firewall and the VPN Gateway bill by the hour** (a few dollars per day combined). This is a lab — destroy it when done:

```bash
terraform destroy
```

To skip the gateway (saves about 30-45 minutes and most of the cost): don't create `vpn.tf`, and set `allow_gateway_transit` and `use_remote_gateways` to `false` in `peering.tf` (Phase 4 explains exactly where).

---

*Provider target: AzureRM v4. If `terraform validate` flags an argument, check the [registry docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) for your pinned version.*
