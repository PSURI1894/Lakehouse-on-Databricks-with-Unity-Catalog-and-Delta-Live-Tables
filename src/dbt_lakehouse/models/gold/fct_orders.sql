{{ config(
    materialized='incremental',
    unique_key='order_id',
    liquid_clustering=['order_date', 'customer_id']
) }}

WITH orders_source AS (
    SELECT
        order_id,
        customer_id,
        product_id,
        amount,
        country_code,
        order_status,
        -- Silver SCD2 fields
        updated_at AS order_date,
        -- Check if it is a current record in SCD2
        __start_at,
        __end_at
    FROM {{ source('silver', 'clean_orders') }}
    
    {% if is_incremental() %}
        -- Incremental extraction logic based on the high water mark
        WHERE updated_at > (SELECT MAX(order_date) FROM {{ this }})
    {% endif %}
),

customers AS (
    SELECT
        customer_id,
        email_address
    FROM {{ ref('dim_customers') }}
),

products AS (
    SELECT
        product_id,
        list_price
    FROM {{ ref('dim_products') }}
)

SELECT
    o.order_id,
    o.customer_id,
    o.product_id,
    o.amount AS gross_amount,
    -- Perform complex enterprise calculation metrics
    CAST(o.amount * 0.08 AS DECIMAL(10, 2)) AS estimated_tax,
    CAST(o.amount * 0.92 AS DECIMAL(10, 2)) AS net_revenue,
    o.country_code,
    o.order_status,
    o.order_date,
    c.email_address AS customer_email,
    p.list_price AS baseline_price,
    -- Audit fields
    CURRENT_TIMESTAMP() AS _dw_processed_ts
FROM orders_source o
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN products p ON o.product_id = p.product_id
