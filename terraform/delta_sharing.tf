# =====================================================================
# UNITY CATALOG SECURE DELTA SHARING CONFIGURATION
# Provisions shares, recipients, and secure table allocations.
# =====================================================================

# 1. Register a secure Delta Share
resource "databricks_share" "gold_share" {
  provider = databricks.us_east
  name     = "enterprise_gold_share"
  comment  = "Secure cross-region share for Gold analytics models"
}

# 2. Add the Gold fact orders table to the share
# Note: The table must be stored in a Unity Catalog schema
resource "databricks_shared_table" "fct_orders_shared" {
  provider   = databricks.us_east
  share_name = databricks_share.gold_share.name
  name       = "prod_catalog.gold.fct_orders"
  comment    = "Shared transactional orders fact table"
}

# 3. Create a Delta Sharing Recipient (e.g., an external region or partner)
resource "databricks_recipient" "west_consumer" {
  provider      = databricks.us_east
  name          = "us_west_recipient"
  authentication_type = "TOKEN"
  comment       = "Recipient token for US-West regional workspace synchronization"
}

# 4. Grant select permissions on the share to the recipient
resource "databricks_grant" "recipient_share_grant" {
  provider   = databricks.us_east
  share      = databricks_share.gold_share.name
  principal  = databricks_recipient.west_consumer.name
  privileges = ["SELECT"]
}
