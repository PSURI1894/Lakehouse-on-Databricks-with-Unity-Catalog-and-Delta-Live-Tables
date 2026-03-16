-- =====================================================================
-- DELTA LAKE NIGHTLY MAINTENANCE & TUNING
-- Executes OPTIMIZE and VACUUM operations to ensure high read/write speeds.
-- =====================================================================

-- 1. Optimize Gold Fact Orders table
-- Since we configured Liquid Clustering, OPTIMIZE runs cluster clustering keys dynamically!
OPTIMIZE dev_catalog.gold.fct_orders;

-- 2. Optimize Gold Customers dimension table
OPTIMIZE dev_catalog.gold.dim_customers;

-- 3. Optimize Federated Products dimension cache
OPTIMIZE dev_catalog.gold.dim_products;

-- 4. Clean up stale historical Delta files (older than 7 days)
-- Employs VACUUM to manage file size bloat and reduce cloud storage expenses.
VACUUM dev_catalog.gold.fct_orders RETAIN 168 HOURS;
VACUUM dev_catalog.gold.dim_customers RETAIN 168 HOURS;
VACUUM dev_catalog.gold.dim_products RETAIN 168 HOURS;
