# Generate random strings for storage account names (must be globally unique and lowercase)
resource "random_string" "storage_suffix" {
  for_each = local.function_apps

  length  = 8
  lower   = true
  upper   = false
  special = false
  numeric = true
}

# Storage accounts for Function Apps
resource "azurerm_storage_account" "function_storage" {
  for_each = local.function_apps

  name                     = "${substr(replace(local.naming_prefixes.storage, "-", ""), 0, 15)}${each.key}${random_string.storage_suffix[each.key].result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_replication_type
  account_kind             = "StorageV2"

  # Security settings
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  # Enable secure transfer
  https_traffic_only_enabled = true

  # Blob properties for security
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
    versioning_enabled = true
  }

  tags = merge(local.common_tags, {
    Purpose = "Function App Storage"
    Service = each.value
  })
}

# App Service Plan for Function Apps
resource "azurerm_service_plan" "function_plan" {
  name                = local.naming_prefixes.appplan
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = var.function_app_sku

  tags = local.common_tags
}

# Application Insights for monitoring Function Apps
resource "azurerm_application_insights" "function_insights" {
  name                = "${local.project_name}-${local.environment}-insights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"

  tags = local.common_tags
}

# Function Apps
resource "azurerm_linux_function_app" "function_apps" {
  for_each = local.function_apps

  name                = "${local.naming_prefixes.functionapp}-${each.key}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.function_plan.id

  storage_account_name       = azurerm_storage_account.function_storage[each.key].name
  storage_account_access_key = azurerm_storage_account.function_storage[each.key].primary_access_key

  # Function App configuration
  site_config {
    always_on                = var.environment == "prod" ? true : false
    use_32_bit_worker        = false
    ftps_state               = "Disabled"
    http2_enabled            = true
    minimum_tls_version      = "1.2"
    scm_minimum_tls_version  = "1.2"
    remote_debugging_enabled = var.environment != "prod"

    # Application stack configuration
    application_stack {
      dotnet_version              = var.function_dotnet_version
      use_dotnet_isolated_runtime = true
    }

    # CORS configuration
    cors {
      allowed_origins     = var.allowed_origins
      support_credentials = false
    }
  }

  # Application settings
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"              = "dotnet-isolated"
    "WEBSITE_RUN_FROM_PACKAGE"              = "1"
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.function_insights.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.function_insights.connection_string

    # Service Bus connection string
    "ServiceBusConnectionString" = azurerm_servicebus_namespace.main.default_primary_connection_string

    # Database connection string (will be set after database creation)
    "DatabaseConnectionString" = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.main.name};Authentication=Active Directory Default;Encrypt=true;TrustServerCertificate=false;Connection Timeout=30;"

    # Environment-specific settings
    "ENVIRONMENT"  = var.environment
    "SERVICE_NAME" = each.value
  }

  # Identity configuration for accessing other Azure resources
  identity {
    type = "SystemAssigned"
  }

  # Enable authentication if required
  dynamic "auth_settings_v2" {
    for_each = var.enable_function_auth ? [1] : []
    content {
      auth_enabled           = true
      require_authentication = true
      unauthenticated_action = "AllowAnonymous"

      default_provider = "azureactivedirectory"

      login {
        token_store_enabled = true
      }

      # Azure AD configuration
      active_directory_v2 {
        client_id                  = var.aad_client_id
        tenant_auth_endpoint       = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
        client_secret_setting_name = "AAD_CLIENT_SECRET"
      }
    }
  }

  tags = merge(local.common_tags, {
    Purpose = "Function App"
    Service = each.value
  })

  depends_on = [
    azurerm_storage_account.function_storage,
    azurerm_application_insights.function_insights,
    azurerm_servicebus_namespace.main,
    azurerm_mssql_database.main
  ]
}

# Function App Slots for staging (production environments only)
resource "azurerm_linux_function_app_slot" "staging" {
  for_each = var.environment == "prod" ? local.function_apps : {}

  name            = "staging"
  function_app_id = azurerm_linux_function_app.function_apps[each.key].id

  storage_account_name       = azurerm_storage_account.function_storage[each.key].name
  storage_account_access_key = azurerm_storage_account.function_storage[each.key].primary_access_key

  site_config {
    always_on                = false
    use_32_bit_worker        = false
    ftps_state               = "Disabled"
    http2_enabled            = true
    minimum_tls_version      = "1.2"
    scm_minimum_tls_version  = "1.2"
    remote_debugging_enabled = true

    application_stack {
      dotnet_version              = var.function_dotnet_version
      use_dotnet_isolated_runtime = true
    }

    cors {
      allowed_origins     = var.allowed_origins
      support_credentials = false
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"              = "dotnet-isolated"
    "WEBSITE_RUN_FROM_PACKAGE"              = "1"
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.function_insights.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.function_insights.connection_string
    "ServiceBusConnectionString"            = azurerm_servicebus_namespace.main.default_primary_connection_string
    "DatabaseConnectionString"              = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.main.name};Authentication=Active Directory Default;Encrypt=true;TrustServerCertificate=false;Connection Timeout=30;"
    "ENVIRONMENT"                           = "staging"
    "SERVICE_NAME"                          = each.value
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(local.common_tags, {
    Purpose = "Function App Staging Slot"
    Service = each.value
    Slot    = "staging"
  })
}