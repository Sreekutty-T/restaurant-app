# Configure the Azure provider


provider "azurerm" {
  features {}

  subscription_id = "***"     # Replace with your subscription ID
  client_id       = "***"     # Replace with your client ID
  client_secret   = "***" # Replace with your client secret
  tenant_id       = "***"     # Replace with your tenant ID
}




# Define Resource Group 
resource "azurerm_resource_group" "example" {
  name     = "rg-restaurant-prod-001"
  location = "eastus"
}



# Kubernetes Cluster (AKS)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-restaurant-prod-001"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "restaurant-aks"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = "production"
  }
}


# Define Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-restaurant-prod-001"
  location            = "eastus2"
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.0.0/16"]
}



# Define Subnet for PostgreSQL
resource "azurerm_subnet" "db_subnet" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "postgresql"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
  depends_on = [ azurerm_virtual_network.vnet ]
}





resource "azurerm_private_dns_zone" "example" {
  name                = "restaurant.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "example" {
  name                  = "exampleVnetZone.com"
  private_dns_zone_name = azurerm_private_dns_zone.example.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.example.name
  depends_on            = [azurerm_subnet.db_subnet]
}



# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "db" {
  name                = "psql-restaurant-prod-001"
  location            = "eastus2" # Ensure this matches the region where the SKU is valid
  resource_group_name = azurerm_resource_group.example.name
  private_dns_zone_id = azurerm_private_dns_zone.example.id
  sku_name            = "B_Standard_B1ms" 
  storage_mb          = 32768
  version             = "16"
  zone                = "1"
  public_network_access_enabled = false
  administrator_login = "adminuser"
  administrator_password = "StrongPassword123!"

  delegated_subnet_id = azurerm_subnet.db_subnet.id

  tags = {
    environment = "production"
  }
   depends_on = [azurerm_private_dns_zone_virtual_network_link.example]
}




resource "azurerm_postgresql_flexible_server_database" "example" {
  name      = "psqldb"
  server_id = azurerm_postgresql_flexible_server.db.id
  collation = "en_US.utf8"
  charset   = "utf8"

  # prevent the possibility of accidental data loss
  lifecycle {
    #prevent_destroy = true
  }
}

# Outputs for Connection
output "postgresql_connection_string" {
  value     = "postgresql://${azurerm_postgresql_flexible_server.db.administrator_login}:${azurerm_postgresql_flexible_server.db.administrator_password}@${azurerm_postgresql_flexible_server.db.fqdn}:5432/${azurerm_postgresql_flexible_server_database.example.name}"
  sensitive = true
}


# Define a Network Security Group (NSG)

resource "azurerm_network_security_group" "example" {
  name                = "sg-restaurant-prod-001"
  location            = "eastus2"
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}


# Associate the Network Security Group with a Subnet
resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.db_subnet.id
  network_security_group_id = azurerm_network_security_group.example.id
}

# Azure container registry
resource "azurerm_container_registry" "acr" {
  name                = "restaurantcs"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Basic"
  admin_enabled       = false
}