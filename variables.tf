variable "subscription_id" {
  type = string
}

variable "location" {
  type = string
}

variable "prefix" {
  type    = string
  default = "shs"
}

variable "vm_admin_username" {
  type    = string
  default = "azureuser"
}

variable "vm_admin_password" {
  type      = string
  sensitive = true
}

variable "sql_admin_username" {
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
    "project" = "secure-hub-spoke"
    "env"     = "lab"
  }
}