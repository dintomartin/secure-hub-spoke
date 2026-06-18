# Phase 7 — Deploy & Validate

**Goal:** create the outputs, apply the whole project, then run a validation suite that proves every security claim. This is the part that turns "I built a network" into "I can demonstrate it works."

File: `outputs.tf`. Then deploy and test.

---

## 7.1 Create `outputs.tf`

These surface the values you need for testing. With explicit resources, each output points at one named resource.

```hcl
output "firewall_private_ip" {
  description = "Next hop used by the spoke route tables."
  value       = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  value = azurerm_public_ip.fw.ip_address
}

output "bastion_name" {
  value = azurerm_bastion_host.main.name
}

output "spoke1_vm_private_ip" {
  value = azurerm_network_interface.spoke1.private_ip_address
}

output "spoke2_vm_private_ip" {
  value = azurerm_network_interface.spoke2.private_ip_address
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "storage_blob_host" {
  description = "Use this for the nslookup test - it should resolve to a 10.x IP."
  value       = "${azurerm_storage_account.main.name}.blob.core.windows.net"
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}
```

---

## 7.2 Deploy

From the project root:

```bash
terraform init
terraform fmt
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

You want `Success! The configuration is valid.` from `validate`. Expect about 30-45 minutes for `apply`, almost all of it the VPN Gateway. Then grab the values you need:

```bash
terraform output
terraform output -raw storage_blob_host
terraform output spoke2_vm_private_ip
```

---

## 7.3 Connect to a test VM

1. Azure Portal, resource group `rg-shs-spoke1`, VM `vm-shs-spoke1`.
2. Choose Connect, then Bastion.
3. Enter the username and password from your tfvars.
4. A browser shell opens. From your laptop (not the VM), confirm the VM has no public IP:

```bash
az vm list-ip-addresses -g rg-shs-spoke1 -n vm-shs-spoke1 -o table
```

✅ **Expected:** the PublicIPAddress column is empty, yet you still got a shell. **(Test 1: no public IPs on workloads.)**

---

## 7.4 The validation suite

Run from inside the spoke VMs via Bastion.

### Test 2 — Outbound internet is filtered by the firewall

From the spoke1 VM:

```bash
curl -sS -o /dev/null -w "%{http_code}\n" https://www.microsoft.com
curl -sS --max-time 10 https://example.com
```

✅ **Pass:** the first prints a status code (around 200); the second times out. The allowed FQDN works, the disallowed one is dropped by the firewall. If both work, the route table is not attached (Phase 4). If both fail, check the application rule FQDNs (Phase 2).

> Confirm from the control side too: in the Portal open the Firewall Policy (or Log Analytics if you wired diagnostics) and you will see the allow for microsoft.com and the deny for example.com. **A screenshot of that deny is the single best piece of evidence for this project.**

### Test 3 — Spoke-to-spoke traffic goes through the firewall

From the spoke1 VM, toward the spoke2 VM's private IP (`terraform output spoke2_vm_private_ip`):

```bash
sudo apt-get update -y
sudo apt-get install -y traceroute
traceroute -n SPOKE2_VM_PRIVATE_IP
```

✅ **Pass:** the first hop is the firewall's private IP (`terraform output firewall_private_ip`), not the spoke2 VM directly. That proves the traffic is forced up to the firewall and inspected. A single direct hop would mean routing is bypassing the firewall.

```bash
ping -c 3 SPOKE2_VM_PRIVATE_IP
```

ICMP works because the firewall network rule allows it.

### Test 4 — Private endpoint resolves to a PRIVATE IP

The headline private-networking test. From the spoke2 VM:

```bash
nslookup STORAGE_BLOB_HOST
```

(Use the value from `terraform output -raw storage_blob_host`.)

✅ **Pass:** the resolved address is a 10.x.x.x private IP from the private-endpoints subnet, not a public IP. That proves the DNS zone, the VNet link, and the endpoint are all working together. A public IP means a missing link or DNS zone group (Phase 5).

```bash
nslookup SQL_SERVER_FQDN
nslookup YOUR_KEYVAULT_NAME.vault.azure.net
```

Both should resolve to 10.x private IPs.

### Test 5 — Public access is genuinely OFF

From your laptop (outside the VNet):

```bash
az storage container list --account-name STORAGE_ACCOUNT_NAME --auth-mode login
```

✅ **Pass:** a network or authorization error showing the public endpoint is disabled — unreachable from outside. From the spoke2 VM, `curl -v https://STORAGE.blob.core.windows.net` should instead reach a TLS handshake or a 400-class service response. Reachable from inside, unreachable from outside, confirms the private-only posture.

### Test 6 — Bastion is the only admin path

```bash
az network nic show -g rg-shs-spoke1 --name nic-vm-shs-spoke1 --query "ipConfigurations[].publicIpAddress" -o tsv
```

✅ **Pass:** empty output. The only way you reached the shell was Bastion.

---

## 7.5 Validation summary table

| # | Claim | How to prove it | Expected result | Evidence |
|---|-------|-----------------|-----------------|----------|
| 1 | No public IPs on workload VMs | `az vm list-ip-addresses` plus Bastion login | Public IP empty, shell still works | screenshot |
| 2 | Egress filtered by firewall | curl allowed vs disallowed FQDN | Allowed 200, disallowed timeout | firewall deny log |
| 3 | Spoke-to-spoke inspected | traceroute spoke1 to spoke2 | First hop is firewall private IP | terminal output |
| 4 | PaaS resolves privately | nslookup storage / SQL / KV | Returns 10.x private IP | terminal output |
| 5 | PaaS public access off | Reach from laptop vs spoke VM | Fails outside, works inside | both outputs |
| 6 | Bastion is sole admin path | `az network nic show` | No public IP on NIC | terminal output |

**The two screenshots worth putting front and center on a portfolio page are the firewall deny log (Test 2) and the nslookup returning a private IP (Test 4).**

---

## 7.6 Troubleshooting quick reference

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Both curls succeed in Test 2 | Route table not associated with the workload subnet | Phase 4 association |
| Spoke-to-spoke fails entirely | `allow_forwarded_traffic = false`, or missing firewall network rule | Phase 4 peering flags, Phase 2 rule |
| traceroute hop is the VM, not the firewall | Missing the `to-spoke` route | Phase 4 routing |
| nslookup returns a public IP | VNet not linked to the DNS zone, or no DNS zone group on the PE | Phase 5 links + zone group |
| apply fails on a subnet | Wrong reserved subnet name | Phase 0 reserved names |
| Spoke peering fails with a gateway error | Gateway did not exist first | Phase 4 `depends_on` |
| VM will not create, password rejected | Password fails Azure complexity | 12-72 chars, 3 of 4 categories |

---

## 7.7 Teardown (do not skip — it bills hourly)

```bash
terraform destroy
```

If destroy hangs on the gateway or DNS links, re-run it, or remove the peerings and gateway first. Confirm in the Portal that `rg-shs-hub`, `rg-shs-spoke1`, and `rg-shs-spoke2` are gone.

---

## 7.8 Where to take it next

- Send firewall and NSG flow logs to Log Analytics and build a workbook.
- Add network security groups per subnet alongside the route tables for defense in depth.
- Switch the firewall to Premium for TLS inspection and IDPS.
- Add a GitHub Actions pipeline running fmt, validate, and plan with remote state and OIDC auth.
- Add `azurerm_local_network_gateway` and `azurerm_virtual_network_gateway_connection` for a real hybrid VPN connection.
- When the repetition starts to bother you, that is the natural moment to refactor the spokes into a module — you will appreciate why modules exist after building it the direct way first.

---

🎉 That is the full project, built with plain flat Terraform. You can deploy a secure hub-spoke network and demonstrate that it behaves correctly — exactly the differentiator you set out to show.
