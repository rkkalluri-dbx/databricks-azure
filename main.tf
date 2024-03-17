terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
    azurerm = {
    }
  }
}



provider "azurerm" {
    features {}
}

provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.myworkspace.id
}

data "azurerm_resource_group" "myresourcegroup" {
  name     = "${var.prefix}-myresourcegroup"
}

resource "azurerm_databricks_workspace" "myworkspace" {
  location                      = data.azurerm_resource_group.myresourcegroup.location
  name                          = "${var.prefix}-workspace"
  resource_group_name           = data.azurerm_resource_group.myresourcegroup.name
  sku                           = "trial"
}

# Use the latest Databricks Runtime
# Long Term Support (LTS) version.
data "databricks_spark_version" "latest_lts" {
  long_term_support = true
}

data "databricks_node_type" "smallest" {
  local_disk = true
}

# Retrieve information about the current user.
data "databricks_current_user" "me" {}

resource "databricks_cluster" "shared_autoscaling" {
  cluster_name            = "${var.prefix}-Autoscaling-Cluster"
  spark_version           = data.databricks_spark_version.latest_lts.id
  node_type_id            = data.databricks_node_type.smallest.id
  autotermination_minutes = 10
  autoscale {
    min_workers = var.min_workers
    max_workers = var.max_workers
  }
  # library {
  #   pypi {
  #       package = "scikit-learn==0.23.2"
  #       // repo can also be specified here
  #       }

  #   }
  # library {
  #   pypi {
  #       package = "fbprophet==0.6"
  #       }
  # }
  custom_tags = {
    Department = "Engineering"
  }
}

resource "databricks_cluster_policy" "this" {
  name = "Minimal (${data.databricks_current_user.me.alphanumeric})"
  definition = jsonencode({
    "dbus_per_hour" : {
      "type" : "range",
      "maxValue" : 10
    },
    "autotermination_minutes" : {
      "type" : "fixed",
      "value" : 20,
      "hidden" : true
    }
  })
}

output "cluster_url" {
 value = databricks_cluster.shared_autoscaling.url
}