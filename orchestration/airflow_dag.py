from datetime import datetime, timedelta
from airflow import DAG
from airflow.models import Variable
from airflow.providers.databricks.operators.databricks import (
    DatabricksRunNowOperator,
    DatabricksSubmitRunOperator,
)
from airflow.sensors.filesystem import FileSensor

# Principal configuration: robust operational parameters
default_args = {
    "owner": "principal_data_platform",
    "depends_on_past": False,
    "email": ["data_alerts@enterprise.com"],
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 3,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    "enterprise_lakehouse_orchestrator",
    default_args=default_args,
    description="Orchestrates dynamic DLT pipelines and downstream dbt models on Databricks SQL",
    schedule_interval="0 4 * * *",  # Nightly at 04:00 AM UTC
    start_date=datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["lakehouse", "dlt", "dbt", "prod"],
) as dag:

    # 1. Wait for raw transactional files to land in S3/ADLS
    wait_for_landing_files = FileSensor(
        task_id="wait_for_landing_files",
        filepath="/mnt/landing/orders/*.json",
        poke_interval=60,
        timeout=3600,
        mode="reschedule",
    )

    # 2. Trigger the dynamic DLT Medallion Pipeline
    # Uses the Databricks provider to run the DLT pipeline
    trigger_dlt_pipeline = DatabricksSubmitRunOperator(
        task_id="trigger_dlt_pipeline",
        databricks_conn_id="databricks_default",
        json={
            "run_name": "Airflow_Triggered_DLT_Ecom",
            "tasks": [
                {
                    "task_key": "dlt_ingest_cleanse",
                    "pipeline_task": {
                        # UUID of the deployed DLT Pipeline
                        "pipeline_id": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d"
                    },
                }
            ],
        },
    )

    # 3. Trigger downstream dbt compilation for the Gold dimensional layer
    # Runs on Databricks SQL Warehouses for maximized analytical compute performance (Photon)
    run_dbt_gold_dimensions = DatabricksSubmitRunOperator(
        task_id="run_dbt_gold_dimensions",
        databricks_conn_id="databricks_default",
        json={
            "run_name": "Airflow_Triggered_dbt_Gold",
            "tasks": [
                {
                    "task_key": "dbt_run",
                    "notebook_task": {
                        "notebook_path": "/Shared/dbt_runner",
                        "base_parameters": {
                            "dbt_command": "dbt run --select path:src/dbt_lakehouse/models/gold",
                            "dbt_profile": "prod",
                        },
                    },
                }
            ],
        },
    )

    # 4. Run data observability and expectation failure audits
    run_observability_audit = DatabricksRunNowOperator(
        task_id="run_observability_audit",
        databricks_conn_id="databricks_default",
        job_id=98765,  # Pre-created Databricks workflow task ID for system audit notebooks
    )

    # Operational flow chain
    wait_for_landing_files >> trigger_dlt_pipeline >> run_dbt_gold_dimensions >> run_observability_audit
