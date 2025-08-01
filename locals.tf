# Local values for naming conventions and common configurations
locals {
  # Naming conventions
  project_name        = var.project_name
  environment         = var.environment
  resource_group_name = "${local.project_name}-${local.environment}-rg"

  # Common tags applied to all resources
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CreatedDate = formatdate("YYYY-MM-DD", timestamp())
    CostCenter  = var.cost_center
  }

  # Naming prefixes for different resource types
  naming_prefixes = {
    vm          = "${local.project_name}-${local.environment}-vm"
    storage     = "${replace(local.project_name, "-", "")}${local.environment}st"
    vnet        = "${local.project_name}-${local.environment}-vnet"
    subnet      = "${local.project_name}-${local.environment}-subnet"
    nsg         = "${local.project_name}-${local.environment}-nsg"
    pip         = "${local.project_name}-${local.environment}-pip"
    nic         = "${local.project_name}-${local.environment}-nic"
    keyvault    = "${replace(local.project_name, "-", "")}${local.environment}kv"
    apim        = "${local.project_name}-${local.environment}-apim"
    functionapp = "${local.project_name}-${local.environment}-func"
    sqlserver   = "${local.project_name}-${local.environment}-sql"
    database    = "${local.project_name}-${local.environment}-db"
    servicebus  = "${local.project_name}-${local.environment}-sb"
    appplan     = "${local.project_name}-${local.environment}-plan"
  }

  # Function App services with their themes
  function_apps = {
    user         = "user-service"
    order        = "order-service"
    payment      = "payment-service"
    notification = "notification-service"
    inventory    = "inventory-service"
    reporting    = "reporting-service"
    audit        = "audit-service"
  }

  # Service Bus topics and queues configuration
  servicebus_config = {
    topics = {
      user_events         = "user-events"
      order_events        = "order-events"
      payment_events      = "payment-events"
      notification_events = "notification-events"
      inventory_events    = "inventory-events"
      reporting_events    = "reporting-events"
      audit_events        = "audit-events"
    }
    queues = {
      user_processing         = "user-processing"
      order_processing        = "order-processing"
      payment_processing      = "payment-processing"
      notification_processing = "notification-processing"
      inventory_processing    = "inventory-processing"
      reporting_processing    = "reporting-processing"
      audit_processing        = "audit-processing"
      deadletter              = "deadletter-queue"
    }
  }
}
