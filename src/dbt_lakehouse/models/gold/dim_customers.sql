{{ config(
    materialized='table',
    liquid_clustering=['customer_id']
) }}

WITH source_data AS (
    SELECT
        customer_id,
        first_name,
        last_name,
        email,
        -- Principal pattern: dynamic hashing on read handled by Unity Catalog policies,
        -- but here we structure clean data forms.
        UPPER(TRIM(first_name)) AS upper_first_name,
        UPPER(TRIM(last_name)) AS upper_last_name,
        email AS email_address,
        updated_at,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY updated_at DESC) as rnk
    FROM {{ source('silver', 'clean_customers') }}
)

SELECT
    customer_id,
    first_name,
    last_name,
    upper_first_name,
    upper_last_name,
    email_address,
    updated_at AS last_updated_at
FROM source_data
WHERE rnk = 1
