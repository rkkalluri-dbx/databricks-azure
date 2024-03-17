terraform {
  required_providers {
    databricks = {
      source = "databrickslabs/databricks"
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

resource "databricks_scim_user" "admin" {
  user_name    = "admin@example.com"
  display_name = "Admin user"
  set_admin    = true
  default_roles = []
}

data "databricks_spark_version" "latest" {}
data "databricks_node_type" "smallest" {
  local_disk = true
}

resource "databricks_cluster" "shared_autoscaling" {
  cluster_name            = "${var.prefix}-Autoscaling-Cluster"
  spark_version           = data.databricks_spark_version.latest
  node_type_id            = data.databricks_node_type.smallest
  autotermination_minutes = 90
  autoscale {
    min_workers = var.min_workers
    max_workers = var.max_workers
  }
  library {
    pypi {
        package = "scikit-learn==0.23.2"
        // repo can also be specified here
        }

    }
  library {
    pypi {
        package = "fbprophet==0.6"
        }
  }
  custom_tags = {
    Department = "Engineering"
  }
}

resource "databricks_notebook" "notebook" {
  content = base64encode("print('Welcome to your Python notebook')")
  path = var.notebook_path
  overwrite = false
  mkdirs = true
  language = "PYTHON"
  format = "SOURCE"
}

resource "databricks_job" "myjob" {
    name = "Featurization"
    timeout_seconds = 3600
    max_retries = 1
    max_concurrent_runs = 1
    existing_cluster_id = databricks_cluster.shared_autoscaling.id

    notebook_task {
        notebook_path = var.notebook_path
    }

    library {
        pypi {
            package = "fbprophet==0.7.1"
        }
    }

    email_notifications {
        no_alert_for_skipped_runs = true
    }
}