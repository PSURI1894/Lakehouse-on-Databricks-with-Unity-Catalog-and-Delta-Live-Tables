-- =====================================================================
-- LAKEHOUSE DATA SECURITY & ENTERPRISE GRANTS
-- Configures dynamic column masks and federation connection privileges.
-- =====================================================================

-- 1. Grant usage privileges on PostgreSQL federated connection
-- This covers connection grants not supported by the TF provider.
GRANT USAGE ON CONNECTION postgres_oltp TO `data_engineers`;
GRANT USAGE ON CONNECTION postgres_oltp TO `bi_analysts`;

-- 2. Create Dynamic Email Masking Function
CREATE OR REPLACE FUNCTION dev_catalog.silver.mask_email(email STRING)
RETURN SELECT CASE
  WHEN IS_MEMBER('payroll_admins') THEN email
  ELSE SHA2(CONCAT(email, 'ENTERPRISE_PII_SALT_98765'), 256)
END;

-- 3. Apply the Column Masking policy to clean_customers table
ALTER TABLE dev_catalog.silver.clean_customers 
ALTER COLUMN email SET MASK dev_catalog.silver.mask_email;

-- 4. Create Dynamic Phone Number Hashing policy
CREATE OR REPLACE FUNCTION dev_catalog.silver.mask_phone(phone STRING)
RETURN SELECT CASE
  WHEN IS_MEMBER('payroll_admins') THEN phone
  ELSE 'XXX-XXX-' || RIGHT(phone, 4)
END;
