# 1. Dev Catalog Provisioning
resource "databricks_catalog" "dev" {
  provider     = databricks.us_east
  name         = "dev_catalog"
  metastore_id = "12345-metastore-us-east"
  comment      = "Sandbox development catalog"
  properties = {
    purpose = "development"
    owner   = "data-platform-team"
  }
}

# 2. Prod Catalog Provisioning
resource "databricks_catalog" "prod" {
  provider     = databricks.us_east
  name         = "prod_catalog"
  metastore_id = "12345-metastore-us-east"
  comment      = "Production-grade enterprise catalog"
  properties = {
    purpose = "production"
    owner   = "data-governance-office"
  }
}

# 3. Schemas in Dev Catalog
resource "databricks_schema" "dev_bronze" {
  provider     = databricks.us_east
  catalog_name = databricks_catalog.dev.name
  name         = "bronze"
  comment      = "Bronze raw append-only schemas"
}

resource "databricks_schema" "dev_silver" {
  provider     = databricks.us_east
  catalog_name = databricks_catalog.dev.name
  name         = "silver"
  comment      = "Silver CDC and expectation filtered schemas"
}

resource "databricks_schema" "dev_gold" {
  provider     = databricks.us_east
  catalog_name = databricks_catalog.dev.name
  name         = "gold"
  comment      = "Gold dimensional marts schema"
}

# 4. Enterprise Roles Access Governance (Grants)
resource "databricks_grants" "catalog_dev_grants" {
  provider = databricks.us_east
  catalog  = databricks_catalog.dev.name

  grant {
    principal  = "data_engineers"
    privileges = ["ALL_PRIVILEGES"]
  }

  grant {
    principal  = "data_scientists"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }

  grant {
    principal  = "bi_analysts"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }
}

resource "databricks_grants" "catalog_prod_grants" {
  provider = databricks.us_east
  catalog  = databricks_catalog.prod.name

  grant {
    principal  = "data_engineers"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT", "MODIFY"]
  }

  grant {
    principal  = "bi_analysts"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }
}
