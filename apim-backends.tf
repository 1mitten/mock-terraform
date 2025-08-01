# APIM Backend configurations for Function Apps
resource "azurerm_api_management_backend" "function_app_backends" {
  for_each = local.function_apps

  name                = "${each.key}-backend"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = "https://${azurerm_linux_function_app.function_apps[each.key].default_hostname}"
  description         = "Backend for ${each.value}"

  # Credentials for Function App authentication
  credentials {
    # Use Function App keys for authentication
    header = {
      "x-functions-key" = "@(context.Variables.GetValueOrDefault(\"${each.key}-function-key\", \"\"))"
    }
  }

  # Proxy configuration
  proxy {
    url      = var.apim_proxy_url
    username = var.apim_proxy_username
    password = var.apim_proxy_password
  }

  # TLS configuration
  tls {
    validate_certificate_chain = true
    validate_certificate_name  = true
  }

  depends_on = [
    azurerm_linux_function_app.function_apps,
    azurerm_api_management.main
  ]
}

# Named Values for Function App Keys (stored securely)
resource "azurerm_api_management_named_value" "function_app_keys" {
  for_each = local.function_apps

  name                = "${each.key}-function-key"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  display_name        = "${title(each.key)} Function Key"
  secret              = true
  value               = "function-key-placeholder-${each.key}" # This should be replaced with actual keys
}

# Backend Pools for load balancing (if needed)
resource "azurerm_api_management_backend" "function_app_pools" {
  for_each = var.enable_apim_load_balancing ? local.function_apps : {}

  name                = "${each.key}-pool"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = "https://${azurerm_linux_function_app.function_apps[each.key].default_hostname}"
  description         = "Load balanced backend pool for ${each.value}"

  # Service Fabric Cluster configuration (if using Service Fabric)
  service_fabric_cluster {
    client_certificate_thumbprint    = var.service_fabric_client_cert_thumbprint
    management_endpoints             = var.service_fabric_management_endpoints
    max_partition_resolution_retries = 5
    server_certificate_thumbprints   = var.service_fabric_server_cert_thumbprints
  }

  depends_on = [
    azurerm_linux_function_app.function_apps,
    azurerm_api_management.main
  ]
}

# Circuit Breaker configuration for backends
resource "azurerm_api_management_backend" "function_app_circuit_breaker" {
  for_each = var.enable_circuit_breaker ? local.function_apps : {}

  name                = "${each.key}-cb-backend"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = "https://${azurerm_linux_function_app.function_apps[each.key].default_hostname}"
  description         = "Circuit breaker backend for ${each.value}"

  # Circuit breaker configuration
  resource_id = azurerm_linux_function_app.function_apps[each.key].id

  credentials {
    certificate = []
    query       = {}
    header = {
      "x-functions-key" = "@(context.Variables.GetValueOrDefault(\"${each.key}-function-key\", \"\"))"
    }
  }

  tls {
    validate_certificate_chain = true
    validate_certificate_name  = true
  }

  depends_on = [
    azurerm_linux_function_app.function_apps,
    azurerm_api_management.main
  ]
}

# Health probes for backends
resource "azurerm_api_management_api_operation" "health_checks" {
  for_each = local.function_apps

  operation_id        = "${each.key}-health"
  api_name            = azurerm_api_management_api.function_app_apis[each.key].name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "${title(each.value)} Health Check"
  method              = "GET"
  url_template        = "/health"
  description         = "Health check endpoint for ${each.value}"

  response {
    status_code = 200
    description = "Healthy"
    representation {
      content_type = "application/json"
      example {
        name = "healthy"
        value = jsonencode({
          status    = "healthy"
          timestamp = "2023-01-01T00:00:00Z"
        })
      }
    }
  }

  response {
    status_code = 503
    description = "Unhealthy"
    representation {
      content_type = "application/json"
      example {
        name = "unhealthy"
        value = jsonencode({
          status    = "unhealthy"
          timestamp = "2023-01-01T00:00:00Z"
        })
      }
    }
  }
}

# API Operation Policies for backend routing
resource "azurerm_api_management_api_operation_policy" "backend_routing" {
  for_each = local.function_apps

  api_name            = azurerm_api_management_api.function_app_apis[each.key].name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  operation_id        = azurerm_api_management_api_operation.health_checks[each.key].operation_id

  xml_content = <<XML
<policies>
  <inbound>
    <set-backend-service backend-id="${azurerm_api_management_backend.function_app_backends[each.key].name}" />
    <set-header name="X-Forwarded-For" exists-action="override">
      <value>@(context.Request.IpAddress)</value>
    </set-header>
    <set-header name="X-Service-Name" exists-action="override">
      <value>${each.value}</value>
    </set-header>
    <base />
  </inbound>
  <backend>
    <retry condition="@(context.Response.StatusCode >= 500)" count="3" interval="1" max-interval="10" delta="1" first-fast-retry="true">
      <base />
    </retry>
  </backend>
  <outbound>
    <set-header name="X-Powered-By" exists-action="delete" />
    <set-header name="Server" exists-action="delete" />
    <base />
  </outbound>
  <on-error>
    <set-status code="500" reason="Internal Server Error" />
    <set-body>@{
      return new JObject(
        new JProperty("error", "An error occurred"),
        new JProperty("message", context.LastError.Message),
        new JProperty("service", "${each.value}")
      ).ToString();
    }</set-body>
    <base />
  </on-error>
</policies>
XML

  depends_on = [
    azurerm_api_management_backend.function_app_backends,
    azurerm_api_management_api_operation.health_checks
  ]
}