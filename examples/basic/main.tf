provider "azurerm" {
  features {}
  subscription_id = "b5c68922-1d40-4a46-bafc-e448fbeb96e1"
}

data "archive_file" "file_function" {
  type        = "zip"
  source_dir  = "${path.module}/../../AzFunctionsApp"
  output_path = "${path.module}/Function.zip"
}

resource "azurerm_resource_group" "rg_monitoringsql" {
  name     = format("rg2-%s-dev-%s", local.logical_name, var.sequential_number)
  location = "North Europe"
}


resource "azurerm_resource_group" "rg_law" {
  name     = "rg-sqlmonitoring-law-01"
  location = "North Europe"
}


resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = format("%s-log-analytics-workspace", local.customer)
  location            = azurerm_resource_group.rg_law.location
  resource_group_name = azurerm_resource_group.rg_law.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_storage_account" "sa_func_app" {
  name                     = format("sa2%s01%s", local.logical_name, local.customer)
  resource_group_name      = azurerm_resource_group.rg_monitoringsql.name
  location                 = azurerm_resource_group.rg_monitoringsql.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "asp_func_app" {
  name                = format("asp2-%s-dev-%s", local.logical_name, var.sequential_number)
  resource_group_name = azurerm_resource_group.rg_monitoringsql.name
  location            = azurerm_resource_group.rg_monitoringsql.location
  os_type             = "Windows"
  sku_name            = "EP1"
}

resource "azurerm_storage_container" "storage_container_func" {
  name                  = format("sc2-%s-%s", local.logical_name, var.sequential_number)
  storage_account_id    = azurerm_storage_account.sa_func_app.id
  container_access_type = "blob"

}

resource "azurerm_storage_blob" "storage_blob_function" {
  name                   = format("function-test-blob-%s", local.customer)
  storage_account_name   = azurerm_storage_account.sa_func_app.name
  storage_container_name = azurerm_storage_container.storage_container_func.name
  type                   = "Block"
  source                 = data.archive_file.file_function.output_path
  content_md5            = data.archive_file.file_function.output_md5

}

resource "azurerm_windows_function_app" "func_app" {
  name                = format("func2-%s-%s-%s", local.logical_name, local.customer, var.sequential_number)
  resource_group_name = azurerm_resource_group.rg_monitoringsql.name
  location            = azurerm_resource_group.rg_monitoringsql.location

  storage_account_name       = azurerm_storage_account.sa_func_app.name
  storage_account_access_key = azurerm_storage_account.sa_func_app.primary_access_key
  service_plan_id            = azurerm_service_plan.asp_func_app.id

  site_config {
    application_insights_key               = azurerm_application_insights.appi.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.appi.connection_string

    cors {
      allowed_origins = ["https://portal.azure.com"]
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE         = azurerm_storage_blob.storage_blob_function.url
    FUNCTIONS_WORKER_RUNTIME         = "powershell"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.appi.instrumentation_key
  }
}

resource "azurerm_application_insights" "appi" {
  name                = format("appi-%s-dev", local.logical_name)
  resource_group_name = azurerm_resource_group.rg_monitoringsql.name
  location            = azurerm_resource_group.rg_monitoringsql.location
  application_type    = "web"
}

resource "azurerm_virtual_network" "test_vnet" {
  name                = "test-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg_monitoringsql.location
  resource_group_name = azurerm_resource_group.rg_monitoringsql.name
}

resource "azurerm_subnet" "subnet1" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.rg_monitoringsql.name
  virtual_network_name = azurerm_virtual_network.test_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_mssql_server" "example" {
  name                         = format("%ssqlserver01", local.customer)
  resource_group_name          = azurerm_resource_group.rg_monitoringsql.name
  location                     = azurerm_resource_group.rg_monitoringsql.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "H@Sh1CoR3!"
}

resource "azurerm_mssql_database" "example" {
  name      = "exampledb2"
  server_id = azurerm_mssql_server.example.id
}

resource "azurerm_private_endpoint" "private_endpoint_sql" {
  name                = "private-endpoint-sql2"
  location            = azurerm_resource_group.rg_monitoringsql.location
  resource_group_name = azurerm_resource_group.rg_monitoringsql.name
  subnet_id           = azurerm_subnet.subnet1.id

  private_service_connection {
    name                           = "privateserviceconnection-sql2"
    private_connection_resource_id = azurerm_mssql_server.example.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
}
# private endpoint für die function app 
resource "azurerm_private_endpoint" "private_endpoint_funcapp" {
  name                = "private-endpoint-funcapp"
  location            = azurerm_resource_group.rg_monitoringsql.location
  resource_group_name = azurerm_resource_group.rg_monitoringsql.name
  subnet_id           = azurerm_subnet.subnet1.id

  private_service_connection {
    name                           = "privateserviceconnection-funcapp"
    private_connection_resource_id = azurerm_windows_function_app.func_app.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }
}
