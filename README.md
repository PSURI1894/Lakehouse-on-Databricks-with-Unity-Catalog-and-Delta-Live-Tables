# Enterprise-Grade Metadata-Driven Lakehouse Platform on Databricks

[![Production Build](https://github.com/enterprise/lakehouse/actions/workflows/ci_cd_pipeline.yml/badge.svg)](https://github.com/enterprise/lakehouse/actions)
[![Databricks](https://img.shields.io/badge/Databricks-Runtime%2014.3%20LTS-orange)](https://docs.databricks.com/release-notes/runtime/14.3lts.html)
[![Delta Lake](https://img.shields.io/badge/Delta_Lake-3.1-blue)](https://delta.io/)
[![dbt](https://img.shields.io/badge/dbt-Core%201.7-red)](https://getdbt.com/)

This repository implements a production-grade, highly-governed, active-active multi-region **Lakehouse Platform** built on Databricks using a **Metadata-Driven ETL Architecture**.

---

## 1. System Architecture In-Depth

The platform processes real-time transaction events (from Apache Kafka) and batch file systems (from S3/ADLS landing zones), implementing a highly-governed Medallion pattern.

```
       +--------------------------------------------+
       |   Ingestion Tier (Kafka + S3 Auto Loader)   |
       +---------------------+----------------------+
                             |
                             v
           +-----------------+------------------+
           |  Bronze Layer (Raw Append-Only)   |  <--- Metadata-Driven Dynamic DLT
           +-----------------+------------------+
                             |
                             v
           +-----------------+------------------+
           |  Silver Layer (CDC SCD1/2 + DQ)    |  <--- Expectations Rules Engine
           +-----------------+------------------+
                             |
                             v
           +-----------------+------------------+
           |   Gold Layer (Star Schema Marts)   |  <--- Compiled via dbt-databricks
           +------------------------------------+
                             |
         +-------------------+-------------------+
         v                                       v
+--------+-----------+                 +---------+----------+
|  Delta UniForm     |                 |  Unity Catalog     |
| (Iceberg Metadata) |                 | (Row/Column Masks) |
+--------------------+                 +--------------------+
```

### Key Engineering Features:
* **Metadata-Driven Framework**: Rather than writing separate pipelines for every new table, a centralized Python engine parses `/src/dlt_engine/metadata/pipelines.yaml` and dynamically constructs Delta Live Tables (DLT) using Spark and Python metaprogramming.
* **Row-Level Security & Hashing**: Unity Catalog dynamic column masks evaluate the user context and apply role-based salting and hashing on PII fields (`email`, `phone`).
* **Active-Active Disaster Recovery**: Storage replication configured via Terraform across US-East (Primary) and US-West (Secondary) cloud sectors.
* **Universal Storage Engine**: Utilizes **Delta UniForm** to generate Iceberg metadata on-the-fly, allowing Snowflake and external engines to query tables directly.

---

## 2. Directory Structure

```
.
├── .github/workflows/          # GitHub Actions multi-stage CI/CD configuration
├── dabs/                       # Databricks Asset Bundles (DABs) definitions
├── notebooks/                  # Observability, security, and Lakehouse Federation SQLs
├── orchestration/              # Apache Airflow DAG definitions
├── src/
│   ├── dlt_engine/             # Metadata-driven DLT Pipeline Engine
│   │   ├── metadata/           # YAML pipeline declaration files
│   │   ├── config_loader.py    # Pydantic schema configurations
│   │   └── pipeline_builder.py # PySpark dynamic register engine
│   └── dbt_lakehouse/          # dbt modeling for the Gold layer
├── tests/                      # Testing framework with PySpark and mock contexts
├── terraform/                  # Infrastructure as Code (Terraform)
├── Makefile                    # Developer lifecycle commands
└── pyproject.toml              # Python standard dependencies and tool configurations
```

---

## 3. Data Governance Model (Unity Catalog)

We structure our catalogs systematically to isolate environments and roles:

* `prod_catalog`: Accessible exclusively by service principals and production BI roles.
* `stage_catalog`: Isolated testing catalog containing sanitized schemas.
* `dev_catalog`: Developer sandbox.

### Dynamic Column Hashing Policy:
```sql
CREATE OR REPLACE FUNCTION mask_pii_email(email STRING)
RETURN SELECT CASE
  WHEN IS_MEMBER('payroll_admins') THEN email
  ELSE SHA2(CONCAT(email, 'ENTERPRISE_SECURE_SALT_128394'), 256)
END;
```

---

## 4. Developer Quickstart

### Prerequisites
* Python 3.10+
* Poetry / pipenv
* Databricks CLI 0.210+
* Terraform 1.5+

### Installation & Local Setup
1. Clone the repository and install developer dependencies:
   ```bash
   make install
   ```
2. Run standard checks and linters:
   ```bash
   make lint
   ```
3. Run local unit tests using mocked Spark setups:
   ```bash
   make test
   ```

### Deploying Asset Bundles (DABs)
To compile and deploy jobs and pipelines to the `development` workspace:
```bash
databricks bundle deploy --target development
```

---

## 5. Monitoring & Observability

Enterprise observability queries are located in `notebooks/sys_observability.sql`. We track:
1. **DBU Spend Breakdown**: Analyzes workspace compute charges over time.
2. **DLT Expectation Leakage**: Monitors the percentage of rows violating Silver expectations (e.g. invalid primary keys or missing values).
3. **Data Freshness (SLA)**: Compares ingestion timestamps (`_ingestion_ts`) with transaction event times to track end-to-end delivery lag.
