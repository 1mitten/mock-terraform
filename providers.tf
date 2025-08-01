# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
    # Enable enhanced features for specific resource types
    api_management {
      purge_soft_delete_on_destroy = true
      recover_soft_deleted         = true
    }

    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }


    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Random provider for generating secure passwords and unique identifiers
provider "random" {
  # Configuration options for the random provider (if needed)
}