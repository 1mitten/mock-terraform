# Core variables for the Azure infrastructure
variable "project_name" {
  description = "Name of the project, used in resource naming"
  type        = string
  default     = "myproject"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "East US"

  validation {
    condition = contains([
      "East US", "East US 2", "West US", "West US 2", "West US 3",
      "Central US", "North Central US", "South Central US", "West Central US",
      "Canada Central", "Canada East", "Brazil South", "UK South", "UK West",
      "West Europe", "North Europe", "France Central", "Germany West Central",
      "Switzerland North", "Norway East", "Sweden Central",
      "Australia East", "Australia Southeast", "East Asia", "Southeast Asia",
      "Japan East", "Japan West", "Korea Central", "India Central",
      "UAE North", "South Africa North"
    ], var.location)
    error_message = "Location must be a valid Azure region."
  }
}

variable "owner" {
  description = "Owner of the resources, used for tagging"
  type        = string
  default     = "DevOps Team"
}

variable "cost_center" {
  description = "Cost center for resource billing and tracking"
  type        = string
  default     = "IT-Infrastructure"
}

variable "allowed_ip_ranges" {
  description = "List of IP ranges allowed to access resources"
  type        = list(string)
  default     = ["0.0.0.0/0"] # This should be restricted in production
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for critical resources"
  type        = bool
  default     = false
}

# Azure Active Directory variables
variable "tenant_id" {
  description = "Azure AD Tenant ID"
  type        = string
  default     = null
}

# API Management variables
variable "apim_publisher_name" {
  description = "The name of the API Management publisher"
  type        = string
  default     = "API Publisher"
}

variable "apim_publisher_email" {
  description = "The email address of the API Management publisher"
  type        = string
  default     = "admin@example.com"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.apim_publisher_email))
    error_message = "Publisher email must be a valid email address."
  }
}

variable "apim_sku_name" {
  description = "SKU for API Management instance"
  type        = string
  default     = "Developer_1"

  validation {
    condition = contains([
      "Developer_1", "Basic_1", "Basic_2", "Standard_1", "Standard_2",
      "Premium_1", "Premium_2", "Premium_4", "Premium_6"
    ], var.apim_sku_name)
    error_message = "APIM SKU must be a valid Azure API Management SKU."
  }
}

variable "apim_virtual_network_type" {
  description = "Virtual network type for API Management"
  type        = string
  default     = "None"

  validation {
    condition     = contains(["None", "External", "Internal"], var.apim_virtual_network_type)
    error_message = "Virtual network type must be None, External, or Internal."
  }
}

variable "apim_proxy_url" {
  description = "Proxy URL for APIM backends"
  type        = string
  default     = null
}

variable "apim_proxy_username" {
  description = "Proxy username for APIM backends"
  type        = string
  default     = null
}

variable "apim_proxy_password" {
  description = "Proxy password for APIM backends"
  type        = string
  default     = null
  sensitive   = true
}

variable "enable_apim_load_balancing" {
  description = "Enable load balancing for APIM backends"
  type        = bool
  default     = false
}

variable "enable_circuit_breaker" {
  description = "Enable circuit breaker for APIM backends"
  type        = bool
  default     = false
}

# Function App variables
variable "function_app_sku" {
  description = "SKU for the App Service Plan hosting Function Apps"
  type        = string
  default     = "Y1"

  validation {
    condition = contains([
      "Y1", "EP1", "EP2", "EP3", "P1V2", "P2V2", "P3V2", "P1V3", "P2V3", "P3V3"
    ], var.function_app_sku)
    error_message = "Function App SKU must be a valid Azure App Service Plan SKU."
  }
}

variable "function_dotnet_version" {
  description = ".NET version for Function Apps"
  type        = string
  default     = "8.0"

  validation {
    condition     = contains(["6.0", "8.0"], var.function_dotnet_version)
    error_message = ".NET version must be 6.0 or 8.0."
  }
}

variable "storage_account_tier" {
  description = "Storage account tier for Function App storage"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_tier)
    error_message = "Storage account tier must be Standard or Premium."
  }
}

variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.storage_replication_type)
    error_message = "Storage replication type must be a valid Azure storage replication type."
  }
}

variable "allowed_origins" {
  description = "Allowed origins for CORS in Function Apps"
  type        = list(string)
  default     = ["https://portal.azure.com"]
}

variable "enable_function_auth" {
  description = "Enable authentication for Function Apps"
  type        = bool
  default     = false
}

variable "aad_client_id" {
  description = "Azure AD Client ID for Function App authentication"
  type        = string
  default     = null
}

# SQL Database variables
variable "sql_admin_username" {
  description = "Administrator username for SQL Server"
  type        = string
  default     = "sqladmin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{2,63}$", var.sql_admin_username))
    error_message = "SQL admin username must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "sql_database_sku" {
  description = "SKU for the SQL Database"
  type        = string
  default     = "S0"

  validation {
    condition     = can(regex("^(Basic|S[0-9]+|P[0-9]+|GP_[A-Za-z0-9_]+|BC_[A-Za-z0-9_]+|HS_[A-Za-z0-9_]+)$", var.sql_database_sku))
    error_message = "SQL Database SKU must be a valid Azure SQL Database SKU."
  }
}

variable "sql_database_max_size_gb" {
  description = "Maximum size of the SQL Database in GB"
  type        = number
  default     = 2

  validation {
    condition     = var.sql_database_max_size_gb >= 1 && var.sql_database_max_size_gb <= 4096
    error_message = "SQL Database max size must be between 1 and 4096 GB."
  }
}

variable "sql_backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7

  validation {
    condition     = var.sql_backup_retention_days >= 1 && var.sql_backup_retention_days <= 35
    error_message = "Backup retention days must be between 1 and 35."
  }
}

variable "sql_public_access_enabled" {
  description = "Enable public network access for SQL Server"
  type        = bool
  default     = true
}

variable "sql_aad_admin_login" {
  description = "Azure AD admin login for SQL Server"
  type        = string
  default     = null
}

variable "sql_aad_admin_object_id" {
  description = "Azure AD admin object ID for SQL Server"
  type        = string
  default     = null
}

variable "sql_aad_only_auth" {
  description = "Enable Azure AD only authentication for SQL Server"
  type        = bool
  default     = false
}

variable "sql_allowed_ip_ranges" {
  description = "List of IP ranges allowed to access SQL Server"
  type        = list(string)
  default     = []
}

variable "security_alert_emails" {
  description = "List of email addresses to receive security alerts"
  type        = list(string)
  default     = []
}

variable "enable_vnet_integration" {
  description = "Enable VNet integration for SQL Server"
  type        = bool
  default     = false
}

variable "sql_subnet_id" {
  description = "Subnet ID for SQL Server VNet integration"
  type        = string
  default     = null
}

variable "tde_key_vault_key_id" {
  description = "Key Vault key ID for Transparent Data Encryption"
  type        = string
  default     = null
}

# Service Bus variables
variable "servicebus_sku" {
  description = "SKU for Service Bus namespace"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.servicebus_sku)
    error_message = "Service Bus SKU must be Basic, Standard, or Premium."
  }
}

variable "servicebus_capacity" {
  description = "Messaging units for Premium Service Bus"
  type        = number
  default     = 1

  validation {
    condition     = var.servicebus_capacity >= 1 && var.servicebus_capacity <= 16
    error_message = "Service Bus capacity must be between 1 and 16 messaging units."
  }
}

variable "servicebus_premium_partitions" {
  description = "Number of partitions for Premium Service Bus"
  type        = number
  default     = 1

  validation {
    condition     = var.servicebus_premium_partitions >= 1 && var.servicebus_premium_partitions <= 4
    error_message = "Service Bus premium partitions must be between 1 and 4."
  }
}

variable "servicebus_public_access_enabled" {
  description = "Enable public network access for Service Bus"
  type        = bool
  default     = true
}

variable "servicebus_enable_partitioning" {
  description = "Enable partitioning for Service Bus topics and queues"
  type        = bool
  default     = false
}

variable "servicebus_topic_max_size" {
  description = "Maximum size in megabytes for Service Bus topics"
  type        = number
  default     = 1024

  validation {
    condition = contains([
      1024, 2048, 3072, 4096, 5120
    ], var.servicebus_topic_max_size)
    error_message = "Service Bus topic max size must be 1024, 2048, 3072, 4096, or 5120 MB."
  }
}

variable "servicebus_queue_max_size" {
  description = "Maximum size in megabytes for Service Bus queues"
  type        = number
  default     = 1024

  validation {
    condition = contains([
      1024, 2048, 3072, 4096, 5120
    ], var.servicebus_queue_max_size)
    error_message = "Service Bus queue max size must be 1024, 2048, 3072, 4096, or 5120 MB."
  }
}

variable "servicebus_default_network_action" {
  description = "Default network access action for Service Bus"
  type        = string
  default     = "Allow"

  validation {
    condition     = contains(["Allow", "Deny"], var.servicebus_default_network_action)
    error_message = "Service Bus default network action must be Allow or Deny."
  }
}

variable "servicebus_allowed_ip_ranges" {
  description = "List of IP ranges allowed to access Service Bus"
  type        = list(string)
  default     = []
}

# Service Fabric variables (for advanced APIM backends)
variable "service_fabric_client_cert_thumbprint" {
  description = "Service Fabric client certificate thumbprint"
  type        = string
  default     = null
}

variable "service_fabric_management_endpoints" {
  description = "Service Fabric management endpoints"
  type        = list(string)
  default     = []
}

variable "service_fabric_server_cert_thumbprints" {
  description = "Service Fabric server certificate thumbprints"
  type        = list(string)
  default     = []
}