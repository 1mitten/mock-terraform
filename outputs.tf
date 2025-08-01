# Output values for the Azure infrastructure
output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the created resource group"
  value       = azurerm_resource_group.main.id
}

output "resource_group_location" {
  description = "Location of the created resource group"
  value       = azurerm_resource_group.main.location
}

output "common_tags" {
  description = "Common tags applied to resources"
  value       = local.common_tags
}

output "naming_prefixes" {
  description = "Naming prefixes for different resource types"
  value       = local.naming_prefixes
  sensitive   = false
}

# API Management Outputs
output "apim_name" {
  description = "Name of the API Management instance"
  value       = azurerm_api_management.main.name
}

output "apim_gateway_url" {
  description = "Gateway URL of the API Management instance"
  value       = azurerm_api_management.main.gateway_url
}

output "apim_management_api_url" {
  description = "Management API URL of the API Management instance"
  value       = azurerm_api_management.main.management_api_url
}

# Function App Outputs
output "function_app_names" {
  description = "Names of all Function Apps"
  value       = { for k, v in azurerm_linux_function_app.function_apps : k => v.name }
}

output "function_app_urls" {
  description = "URLs of all Function Apps"
  value       = { for k, v in azurerm_linux_function_app.function_apps : k => v.default_hostname }
}

output "function_app_identities" {
  description = "System-assigned identities of Function Apps"
  value       = { for k, v in azurerm_linux_function_app.function_apps : k => v.identity[0].principal_id }
}

# Storage Account Outputs
output "function_storage_accounts" {
  description = "Storage account names for Function Apps"
  value       = { for k, v in azurerm_storage_account.function_storage : k => v.name }
}

# Database Outputs
output "sql_server_name" {
  description = "Name of the SQL Server"
  value       = azurerm_mssql_server.main.name
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL Server"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Name of the SQL Database"
  value       = azurerm_mssql_database.main.name
}

output "sql_connection_string" {
  description = "Connection string for the SQL Database (without credentials)"
  value       = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.main.name};Encrypt=true;TrustServerCertificate=false;Connection Timeout=30;"
  sensitive   = false
}

# Service Bus Outputs
output "servicebus_namespace_name" {
  description = "Name of the Service Bus namespace"
  value       = azurerm_servicebus_namespace.main.name
}

output "servicebus_connection_string" {
  description = "Primary connection string for Service Bus namespace"
  value       = azurerm_servicebus_namespace.main.default_primary_connection_string
  sensitive   = true
}

output "servicebus_topics" {
  description = "Names of all Service Bus topics"
  value       = { for k, v in azurerm_servicebus_topic.topics : k => v.name }
}

output "servicebus_queues" {
  description = "Names of all Service Bus queues"
  value       = { for k, v in azurerm_servicebus_queue.queues : k => v.name }
}

# Application Insights Outputs
output "application_insights_name" {
  description = "Name of the Application Insights instance"
  value       = azurerm_application_insights.function_insights.name
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = azurerm_application_insights.function_insights.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.function_insights.connection_string
  sensitive   = true
}

# Service Plan Output
output "service_plan_name" {
  description = "Name of the App Service Plan"
  value       = azurerm_service_plan.function_plan.name
}

# APIM Backend Outputs
output "apim_backend_names" {
  description = "Names of all APIM backends"
  value       = { for k, v in azurerm_api_management_backend.function_app_backends : k => v.name }
}

# Summary Output
output "infrastructure_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    resource_group = azurerm_resource_group.main.name
    location       = azurerm_resource_group.main.location
    environment    = var.environment
    project_name   = var.project_name
    apim_gateway   = azurerm_api_management.main.gateway_url
    function_apps  = length(local.function_apps)
    sql_server     = azurerm_mssql_server.main.fully_qualified_domain_name
    servicebus     = azurerm_servicebus_namespace.main.name
    topics_count   = length(local.servicebus_config.topics)
    queues_count   = length(local.servicebus_config.queues)
  }
}