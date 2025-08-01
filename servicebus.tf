# Azure Service Bus Namespace
resource "azurerm_servicebus_namespace" "main" {
  name                = local.naming_prefixes.servicebus
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = var.servicebus_sku
  capacity            = var.servicebus_sku == "Premium" ? var.servicebus_capacity : null

  # Premium tier features
  premium_messaging_partitions = var.servicebus_sku == "Premium" ? var.servicebus_premium_partitions : null

  # Public network access
  public_network_access_enabled = var.servicebus_public_access_enabled
  minimum_tls_version           = "1.2"

  # Network rule set (for Premium tier)
  dynamic "network_rule_set" {
    for_each = var.servicebus_sku == "Premium" ? [1] : []
    content {
      default_action                = var.servicebus_default_network_action
      public_network_access_enabled = var.servicebus_public_access_enabled
      trusted_services_allowed      = true
      ip_rules                      = var.servicebus_allowed_ip_ranges
    }
  }

  # Identity for accessing other Azure resources
  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Service Bus Topics for event-driven communication
resource "azurerm_servicebus_topic" "topics" {
  for_each = local.servicebus_config.topics

  name         = each.value
  namespace_id = azurerm_servicebus_namespace.main.id

  # Topic settings
  partitioning_enabled                    = var.servicebus_enable_partitioning
  max_size_in_megabytes                   = var.servicebus_topic_max_size
  requires_duplicate_detection            = true
  duplicate_detection_history_time_window = "PT10M"

  # Message retention
  default_message_ttl = "P14D" # 14 days

  # Dead lettering
  batched_operations_enabled = true
}

# Service Bus Queues for direct processing
resource "azurerm_servicebus_queue" "queues" {
  for_each = local.servicebus_config.queues

  name         = each.value
  namespace_id = azurerm_servicebus_namespace.main.id

  # Queue settings
  partitioning_enabled                    = var.servicebus_enable_partitioning
  max_size_in_megabytes                   = var.servicebus_queue_max_size
  requires_duplicate_detection            = true
  duplicate_detection_history_time_window = "PT10M"

  # Message handling
  default_message_ttl = "P14D" # 14 days
  max_delivery_count  = 10
  lock_duration       = "PT5M" # 5 minutes
  requires_session    = false

  # Dead lettering
  dead_lettering_on_message_expiration = true
  batched_operations_enabled           = true
}

# Service Bus Subscriptions for topics
resource "azurerm_servicebus_subscription" "topic_subscriptions" {
  for_each = {
    for combo in setproduct(keys(local.servicebus_config.topics), keys(local.function_apps)) :
    "${combo[0]}-${combo[1]}" => {
      topic_key    = combo[0]
      service_key  = combo[1]
      topic_name   = local.servicebus_config.topics[combo[0]]
      service_name = local.function_apps[combo[1]]
    }
  }

  name     = "${each.value.service_name}-subscription"
  topic_id = azurerm_servicebus_topic.topics[each.value.topic_key].id

  # Subscription settings
  max_delivery_count  = 10
  lock_duration       = "PT5M" # 5 minutes
  requires_session    = false
  default_message_ttl = "P14D" # 14 days

  # Dead lettering
  dead_lettering_on_message_expiration      = true
  dead_lettering_on_filter_evaluation_error = true
  batched_operations_enabled                = true

  # Auto delete on idle
  auto_delete_on_idle = "P10675199DT2H48M5.4775807S" # Max value
}

# Service Bus Subscription Rules (filters)
resource "azurerm_servicebus_subscription_rule" "service_filters" {
  for_each = {
    for combo in setproduct(keys(local.servicebus_config.topics), keys(local.function_apps)) :
    "${combo[0]}-${combo[1]}" => {
      topic_key    = combo[0]
      service_key  = combo[1]
      topic_name   = local.servicebus_config.topics[combo[0]]
      service_name = local.function_apps[combo[1]]
    }
    if combo[0] == combo[1] # Only create filters for matching service types
  }

  name            = "ServiceFilter"
  subscription_id = azurerm_servicebus_subscription.topic_subscriptions["${each.value.topic_key}-${each.value.service_key}"].id
  filter_type     = "SqlFilter"
  sql_filter      = "ServiceType = '${each.value.service_name}'"
}

# Service Bus Authorization Rules for Function Apps
resource "azurerm_servicebus_namespace_authorization_rule" "function_apps" {
  name         = "function-apps-access"
  namespace_id = azurerm_servicebus_namespace.main.id

  listen = true
  send   = true
  manage = false
}

# Individual authorization rules for each service (fine-grained access)
resource "azurerm_servicebus_topic_authorization_rule" "topic_rules" {
  for_each = local.servicebus_config.topics

  name     = "${each.key}-topic-access"
  topic_id = azurerm_servicebus_topic.topics[each.key].id

  listen = true
  send   = true
  manage = false
}

resource "azurerm_servicebus_queue_authorization_rule" "queue_rules" {
  for_each = local.servicebus_config.queues

  name     = "${each.key}-queue-access"
  queue_id = azurerm_servicebus_queue.queues[each.key].id

  listen = true
  send   = true
  manage = false
}


# Diagnostic Settings for Service Bus
resource "azurerm_monitor_diagnostic_setting" "servicebus" {
  name               = "${local.naming_prefixes.servicebus}-diagnostics"
  target_resource_id = azurerm_servicebus_namespace.main.id

  # You would typically send logs to Log Analytics, Storage Account, or Event Hub
  # For this example, we'll use a storage account for logs
  storage_account_id = azurerm_storage_account.diagnostics.id

  # Logs
  enabled_log {
    category = "OperationalLogs"
  }

  enabled_log {
    category = "VNetAndIPFilteringLogs"
  }

  # Metrics
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Storage account for diagnostics
resource "azurerm_storage_account" "diagnostics" {
  name                     = "${substr(replace(local.naming_prefixes.storage, "-", ""), 0, 15)}diag${random_string.diag_suffix.result}"
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
    Purpose = "Service Bus Diagnostics"
  })
}

# Random suffix for diagnostics storage account
resource "random_string" "diag_suffix" {
  length  = 8
  lower   = true
  upper   = false
  special = false
  numeric = true
}