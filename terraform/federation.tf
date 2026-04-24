# 1. PostgreSQL Federated Transactional database connection
resource "databricks_connection" "postgres" {
  provider        = databricks.us_east
  name            = "postgres_oltp"
  connection_type = "postgresql"
  options = {
    host     = "rds-postgres-production.abcdef.us-east-1.rds.amazonaws.com"
    port     = "5432"
    user     = "enterprise_reader"
    password = "SecurePassword128394_Mock"
  }
  comment = "Operational transactional database link for catalog virtualization"
}

# 2. Snowflake Federated Enterprise Data Warehouse connection
resource "databricks_connection" "snowflake" {
  provider        = databricks.us_east
  name            = "snowflake_edw"
  connection_type = "snowflake"
  options = {
    sfUrl      = "https://xy12345.us-east-1.snowflakecomputing.com"
    sfUser     = "DATABRICKS_READER"
    sfPassword = "SecurePassword128394_SnowflakeMock"
    sfDatabase = "PROD_EDW"
    sfWarehouse= "ANALYTICS_WH"
  }
  comment = "Enterprise DW link for historical reporting and validation queries"
}

# 3. Connection access privileges for engineering and analyst roles
resource "databricks_grants" "postgres_connection_grants" {
  provider = databricks.us_east
  connection = databricks_connection.postgres.name

  grant {
    principal  = "data_engineers"
    privileges = ["ALL_PRIVILEGES"]
  }

  grant {
    principal  = "bi_analysts"
    privileges = ["READ_FILES"]
  }
}
