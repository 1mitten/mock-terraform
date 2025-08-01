# Generate random password for SQL Server admin
resource "random_password" "sql_admin_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Azure SQL Server
resource "azurerm_mssql_server" "main" {
  name                         = local.naming_prefixes.sqlserver
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = random_password.sql_admin_password.result
  minimum_tls_version          = "1.2"

  # Public network access - should be disabled in production
  public_network_access_enabled = var.sql_public_access_enabled

  # Azure AD integration
  azuread_administrator {
    login_username              = var.sql_aad_admin_login
    object_id                   = var.sql_aad_admin_object_id
    tenant_id                   = var.tenant_id
    azuread_authentication_only = var.sql_aad_only_auth
  }

  # Identity for accessing other Azure resources
  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Azure SQL Database
resource "azurerm_mssql_database" "main" {
  name           = local.naming_prefixes.database
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = var.sql_database_max_size_gb
  sku_name       = var.sql_database_sku
  zone_redundant = var.environment == "prod" ? true : false

  # Automatic backup settings
  short_term_retention_policy {
    retention_days = var.sql_backup_retention_days
  }

  # Long term backup retention (for production)
  dynamic "long_term_retention_policy" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      weekly_retention  = "P4W"
      monthly_retention = "P12M"
      yearly_retention  = "P5Y"
      week_of_year      = 1
    }
  }

  # Threat detection policy
  threat_detection_policy {
    state                      = "Enabled"
    email_account_admins       = "Enabled"
    email_addresses            = var.security_alert_emails
    retention_days             = 30
    storage_account_access_key = azurerm_storage_account.sql_audit.primary_access_key
    storage_endpoint           = azurerm_storage_account.sql_audit.primary_blob_endpoint
  }

  tags = local.common_tags
}

# Storage account for SQL auditing
resource "azurerm_storage_account" "sql_audit" {
  name                     = "${substr(replace(local.naming_prefixes.storage, "-", ""), 0, 15)}sqlaudit${random_string.sql_audit_suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true

  blob_properties {
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
    versioning_enabled = true
  }

  tags = merge(local.common_tags, {
    Purpose = "SQL Audit Storage"
  })
}

# Random suffix for SQL audit storage account
resource "random_string" "sql_audit_suffix" {
  length  = 8
  lower   = true
  upper   = false
  special = false
  numeric = true
}

# SQL Server Auditing
resource "azurerm_mssql_server_extended_auditing_policy" "main" {
  server_id                  = azurerm_mssql_server.main.id
  enabled                    = true
  storage_endpoint           = azurerm_storage_account.sql_audit.primary_blob_endpoint
  storage_account_access_key = azurerm_storage_account.sql_audit.primary_access_key
  retention_in_days          = 90
  log_monitoring_enabled     = true
}

# Database Auditing
resource "azurerm_mssql_database_extended_auditing_policy" "main" {
  database_id                = azurerm_mssql_database.main.id
  enabled                    = true
  storage_endpoint           = azurerm_storage_account.sql_audit.primary_blob_endpoint
  storage_account_access_key = azurerm_storage_account.sql_audit.primary_access_key
  retention_in_days          = 90
  log_monitoring_enabled     = true
}

# Firewall rules for SQL Server
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Firewall rules for allowed IP ranges
resource "azurerm_mssql_firewall_rule" "allowed_ips" {
  count = length(var.sql_allowed_ip_ranges)

  name             = "AllowedIP${count.index + 1}"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = split("/", var.sql_allowed_ip_ranges[count.index])[0]
  end_ip_address   = split("/", var.sql_allowed_ip_ranges[count.index])[0]
}

# SQL Server Virtual Network Rule (if using VNet integration)
resource "azurerm_mssql_virtual_network_rule" "main" {
  count = var.enable_vnet_integration ? 1 : 0

  name      = "sql-vnet-rule"
  server_id = azurerm_mssql_server.main.id
  subnet_id = var.sql_subnet_id
}

# Transparent Data Encryption
resource "azurerm_mssql_server_transparent_data_encryption" "main" {
  server_id        = azurerm_mssql_server.main.id
  key_vault_key_id = var.tde_key_vault_key_id
}

# Advanced Threat Protection
resource "azurerm_mssql_server_security_alert_policy" "main" {
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mssql_server.main.name
  state               = "Enabled"

  disabled_alerts      = []
  email_account_admins = true
  email_addresses      = var.security_alert_emails
  retention_days       = 30

  storage_account_access_key = azurerm_storage_account.sql_audit.primary_access_key
  storage_endpoint           = azurerm_storage_account.sql_audit.primary_blob_endpoint
}

# Vulnerability Assessment
resource "azurerm_mssql_server_vulnerability_assessment" "main" {
  server_security_alert_policy_id = azurerm_mssql_server_security_alert_policy.main.id
  storage_container_path          = "${azurerm_storage_account.sql_audit.primary_blob_endpoint}vulnerability-assessment/"
  storage_account_access_key      = azurerm_storage_account.sql_audit.primary_access_key

  recurring_scans {
    enabled                   = true
    email_subscription_admins = true
    emails                    = var.security_alert_emails
  }
}