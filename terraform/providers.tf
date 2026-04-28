terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.35.0"
    }
  }
}

# AWS Regions setup for active-active storage setup
provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_west"
  region = "us-west-2"
}

# Databricks providers bound to regional metastores
provider "databricks" {
  alias = "us_east"
  host  = var.databricks_host_east
  token = var.databricks_token_east
}

provider "databricks" {
  alias = "us_west"
  host  = var.databricks_host_west
  token = var.databricks_token_west
}

# Root variables declaration
variable "databricks_host_east" {
  type    = string
  default = "https://adb-east.azuredatabricks.net"
}

variable "databricks_token_east" {
  type      = string
  sensitive = true
  default   = "mock_token_east"
}

variable "databricks_host_west" {
  type    = string
  default = "https://adb-west.azuredatabricks.net"
}

variable "databricks_token_west" {
  type      = string
  sensitive = true
  default   = "mock_token_west"
}
