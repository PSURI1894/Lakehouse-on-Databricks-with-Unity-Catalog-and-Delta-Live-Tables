# =====================================================================
# UNITY CATALOG SECURE DELTA SHARING CONFIGURATION
# Provisions shares, recipients, and secure table allocations.
# =====================================================================

# 1. Register a secure Delta Share with nested shared tables
resource "databricks_share" "gold_share" {
  provider = databricks.us_east
  name     = "enterprise_gold_share"

  # Shared tables are configured as nested object blocks in provider v1.35.0
  object {
    name             = "prod_catalog.gold.fct_orders"
    data_object_type = "TABLE"
    comment          = "Shared transactional orders fact table"
  }
}

# 2. Create a Delta Sharing Recipient (e.g., an external region or partner)
resource "databricks_recipient" "west_consumer" {
  provider      = databricks.us_east
  name          = "us_west_recipient"
  authentication_type = "TOKEN"
  comment       = "Recipient token for US-West regional workspace synchronization"
}

# 3. Grant select privileges on the share to the recipient
resource "databricks_grant" "recipient_share_grant" {
  provider   = databricks.us_east
  share      = databricks_share.gold_share.name
  principal  = databricks_recipient.west_consumer.name
  privileges = ["SELECT"]
}
