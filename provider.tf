terraform {

  required_version = ">=0.12"
  
  required_providers {

  }
}

provider "azurerm" {
  features {}

  subscription_id   = "9dc6b762-c8ca-4625-bcca-14f73ae7f41c"
  tenant_id         = "8cb22c49-70bc-45b0-9fdf-7a529cd86ea1"
  client_id         = "b31e2f38-061a-47c9-b3fe-23319b6281fd"
  client_secret     = "xxx"
}