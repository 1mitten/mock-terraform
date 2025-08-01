# Azure API Management Instance
resource "azurerm_api_management" "main" {
  name                = local.naming_prefixes.apim
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = var.apim_sku_name

  # Identity configuration for API Management
  identity {
    type = "SystemAssigned"
  }

  # Security and networking configuration
  security {
    enable_backend_ssl30                                = false
    enable_backend_tls10                                = false
    enable_backend_tls11                                = false
    enable_frontend_ssl30                               = false
    enable_frontend_tls10                               = false
    enable_frontend_tls11                               = false
    tls_ecdhe_ecdsa_with_aes128_cbc_sha_ciphers_enabled = false
    tls_ecdhe_ecdsa_with_aes256_cbc_sha_ciphers_enabled = false
    tls_rsa_with_aes128_cbc_sha256_ciphers_enabled      = false
    tls_rsa_with_aes256_cbc_sha256_ciphers_enabled      = false
    tls_rsa_with_aes128_cbc_sha_ciphers_enabled         = false
    tls_rsa_with_aes256_cbc_sha_ciphers_enabled         = false
  }

  # Protocols configuration
  protocols {
    enable_http2 = true
  }

  # Virtual network type (None for external, Internal for internal access)
  virtual_network_type = var.apim_virtual_network_type

  tags = local.common_tags
}

# API Management Product for Function Apps
resource "azurerm_api_management_product" "function_apps" {
  product_id            = "function-apps-product"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = azurerm_resource_group.main.name
  display_name          = "Function Apps Product"
  description           = "Product for all Function App APIs"
  subscription_required = true
  approval_required     = false
  published             = true
}

# API Management APIs for each Function App
resource "azurerm_api_management_api" "function_app_apis" {
  for_each = local.function_apps

  name                  = "${each.key}-api"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = azurerm_resource_group.main.name
  revision              = "1"
  display_name          = "${title(each.value)} API"
  description           = "API for ${each.value}"
  protocols             = ["https"]
  service_url           = "https://${local.naming_prefixes.functionapp}-${each.key}.azurewebsites.net"
  path                  = each.key
  subscription_required = true

  import {
    content_format = "openapi-link"
    content_value  = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/master/specification/apimanagement/resource-manager/Microsoft.ApiManagement/stable/2021-08-01/examples/ApiManagementCreateApiUsingSwaggerImport.json"
  }
}

# Associate APIs with the Product
resource "azurerm_api_management_product_api" "function_app_product_apis" {
  for_each = local.function_apps

  api_name            = azurerm_api_management_api.function_app_apis[each.key].name
  product_id          = azurerm_api_management_product.function_apps.product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
}

# API Management Policy for rate limiting and security
resource "azurerm_api_management_api_policy" "function_app_policies" {
  for_each = local.function_apps

  api_name            = azurerm_api_management_api.function_app_apis[each.key].name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name

  xml_content = <<XML
<policies>
  <inbound>
    <rate-limit calls="100" renewal-period="60" />
    <quota calls="1000" renewal-period="86400" />
    <base />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}