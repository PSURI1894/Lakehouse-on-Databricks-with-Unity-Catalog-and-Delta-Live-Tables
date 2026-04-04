{{ config(
    materialized='table',
    liquid_clustering=['product_id']
) }}

-- Principal pattern: Lakehouse Federation virtual table caching
-- Queries the live transactional database via Unity Catalog connection
WITH external_products AS (
    SELECT
        product_id,
        product_name,
        category,
        list_price,
        supplier_id,
        updated_at
    FROM {{ source('postgres_oltp', 'products') }}
)

SELECT
    product_id,
    TRIM(product_name) AS product_name,
    COALESCE(category, 'GENERAL') AS category,
    CAST(list_price AS DECIMAL(10, 2)) AS list_price,
    supplier_id,
    updated_at AS sync_timestamp
FROM external_products
