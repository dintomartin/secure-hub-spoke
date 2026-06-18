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