-- =====================================================================
-- ENTERPRISE LAKEHOUSE SYSTEM OBSERVABILITY & FINOPS
-- Audits system billing, expectation failures, and Photon compute efficiency.
-- =====================================================================

-- 1. DBU Spend Auditing (FinOps)
-- Groups workspace costs by SKU, Compute Resource, and Day to identify cost spikes.
SELECT
  usage_date,
  sku_name,
  usage_metadata.cluster_id AS cluster_id,
  SUM(usage_quantity) AS total_dbus,
  SUM(usage_quantity * pricing.default_list_price) AS total_cost_usd
FROM
  system.billing.usage
WHERE
  usage_date >= CURRENT_DATE() - INTERVAL 30 DAYS
  AND billing_origin_product = 'DATABRICKS'
GROUP BY
  1, 2, 3
ORDER BY
  total_cost_usd DESC
LIMIT 50;

-- 2. DLT Quality Expectations Auditing
-- Parses the DLT event log JSON payloads to monitor pipeline expectation compliance.
WITH expectation_events AS (
  SELECT
    id AS event_id,
    timestamp,
    message,
    details:flow_definition.flow_name AS flow_name,
    details:flow_progress.metrics.expectations AS expectations_array
  FROM
    event_log("a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d") -- DLT Pipeline ID
  WHERE
    event_type = 'flow_progress'
    AND details:flow_progress.metrics.expectations IS NOT NULL
),

exploded_expectations AS (
  SELECT
    timestamp,
    flow_name,
    explode(expectations_array) AS expectation_detail
  FROM
    expectation_events
)

SELECT
  timestamp,
  flow_name,
  expectation_detail.name AS rule_name,
  expectation_detail.passed_records AS passed_records,
  expectation_detail.failed_records AS failed_records,
  CAST(expectation_detail.failed_records AS DOUBLE) / 
    NULLIF(expectation_detail.passed_records + expectation_detail.failed_records, 0) * 100 AS expectation_failure_percentage
FROM
  exploded_expectations
ORDER BY
  timestamp DESC;

-- 3. Query Performance & Photon Vectorization Audit
-- Profiles query histories to evaluate execution efficiency, compilation, and cache hit metrics.
SELECT
  query_id,
  user_name,
  statement_text,
  total_duration_ms,
  compilation_duration_ms,
  execution_duration_ms,
  -- Vectorized engine performance
  metrics.photonCpuTimeMs AS photon_cpu_time_ms,
  metrics.readBytesFromCache AS read_bytes_from_cache,
  metrics.readBytesFromCloud AS read_bytes_from_cloud,
  CAST(metrics.readBytesFromCache AS DOUBLE) / 
    NULLIF(metrics.readBytesFromCache + metrics.readBytesFromCloud, 0) * 100 AS cache_hit_ratio
FROM
  system.query_history
WHERE
  start_time >= CURRENT_TIMESTAMP() - INTERVAL 7 DAYS
  AND total_duration_ms > 5000 -- Slow queries only
ORDER BY
  total_duration_ms DESC
LIMIT 100;

-- 4. Cross-Region Egress Auditing (Lineage & Compliance)
-- Monitors tables exported to external sharing recipients via Delta Sharing.
SELECT
  event_time,
  action_name,
  request_params.recipient AS sharing_recipient,
  request_params.share AS share_name,
  request_params.table AS shared_table,
  response.status AS request_status
FROM
  system.access.audit
WHERE
  service_name = 'unityCatalog'
  AND action_name IN ('getShare', 'getTableInShare', 'accessShare')
ORDER BY
  event_time DESC;
