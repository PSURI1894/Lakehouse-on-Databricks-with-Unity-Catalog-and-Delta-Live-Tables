import sys
from typing import Any, Callable, Dict, List
from src.dlt_engine.config_loader import PipelineConfig, TableConfig, load_config

# Secure dynamic import for Databricks DLT execution context.
# When run locally during pytest, it falls back to mock implementations.
try:
    import dlt
    from pyspark.sql import DataFrame
    from pyspark.sql.functions import current_timestamp, input_file_name
except ImportError:
    # Local mock classes for off-cluster unit testing validation.
    class MockDLT:
        def table(self, *args: Any, **kwargs: Any) -> Callable:
            def decorator(f: Callable) -> Callable:
                return f

            return decorator

        def create_streaming_table(self, *args: Any, **kwargs: Any) -> None:
            pass

        def apply_changes(self, *args: Any, **kwargs: Any) -> None:
            pass

        def expect_all(self, *args: Any, **kwargs: Any) -> Callable:
            def decorator(f: Callable) -> Callable:
                return f

            return decorator

        def expect_all_or_drop(self, *args: Any, **kwargs: Any) -> Callable:
            def decorator(f: Callable) -> Callable:
                return f

            return decorator

        def expect_all_or_fail(self, *args: Any, **kwargs: Any) -> Callable:
            def decorator(f: Callable) -> Callable:
                return f

            return decorator

    dlt = MockDLT()  # type: ignore


class DltPipelineCompiler:
    """Enterprise compiler engine that programmatically compiles YAML schema models

    into Delta Live Tables streams, CDC merges, and expectation bounds.
    """

    def __init__(self, config_path: str) -> None:
        self.pipelines: List[PipelineConfig] = load_config(config_path)

    def compile(self, spark_session: Any) -> None:
        """Iterates over pipeline definitions and programmatically registers them

        with the Databricks DLT compilation context.
        """
        for pipeline in self.pipelines:
            if pipeline.layer == "bronze":
                self._compile_bronze(pipeline, spark_session)
            elif pipeline.layer == "silver":
                self._compile_silver(pipeline, spark_session)

    def _compile_bronze(self, pipeline: PipelineConfig, spark: Any) -> None:
        for table in pipeline.tables:
            self._register_bronze_table(table, spark)

    def _register_bronze_table(self, table: TableConfig, spark: Any) -> None:
        table_name = table.name
        source_path = table.source_path or ""
        file_format = table.cloud_files_format or "json"
        evolution = table.schema_evolution_mode or "addNewColumns"

        # Dynamically compile Auto Loader structure
        def make_bronze_stream() -> Any:
            reader = (
                spark.readStream.format("cloudFiles")
                .option("cloudFiles.format", file_format)
                .option("cloudFiles.schemaEvolutionMode", evolution)
            )
            if table.csv_header:
                reader = reader.option("header", "true")

            return (
                reader.load(source_path)
                .withColumn("_file_path", input_file_name())
                .withColumn("_ingestion_ts", current_timestamp())
            )

        # Register inside global namespace dynamically so DLT compiler compiles it
        dlt_table_decorator = dlt.table(
            name=table_name,
            comment=f"Dynamic Bronze Table: Source data from {source_path}",
            table_properties={
                "quality": "bronze",
                "pii_leakage": str(table.tags.pii if table.tags else "false"),
            },
        )
        globals()[table_name] = dlt_table_decorator(make_bronze_stream)

    def _compile_silver(self, pipeline: PipelineConfig, spark: Any) -> None:
        for table in pipeline.tables:
            if table.cdc and table.cdc.enabled:
                self._register_silver_cdc_table(table)
            else:
                self._register_silver_standard_table(table, spark)

    def _register_silver_standard_table(self, table: TableConfig, spark: Any) -> None:
        table_name = table.name
        source_table = table.source_table or ""
        expectations = table.expectations or {}

        # Extract and group rules dynamically
        warn_rules = {k: v.expr for k, v in expectations.items() if v.action == "WARN"}
        drop_rules = {k: v.expr for k, v in expectations.items() if v.action == "DROP"}
        fail_rules = {k: v.expr for k, v in expectations.items() if v.action == "FAIL"}

        def make_silver_stream() -> Any:
            return dlt.read_stream(source_table)

        # Build pipeline dynamic decorator chain
        decorated_func = make_silver_stream
        if warn_rules:
            decorated_func = dlt.expect_all(warn_rules)(decorated_func)
        if drop_rules:
            decorated_func = dlt.expect_all_or_drop(drop_rules)(decorated_func)
        if fail_rules:
            decorated_func = dlt.expect_all_or_fail(fail_rules)(decorated_func)

        dlt_table_decorator = dlt.table(
            name=table_name,
            comment=f"Dynamic Silver Table: Cleansed from {source_table}",
            table_properties={
                "quality": "silver",
                "liquid_clustering": str(table.clustering_keys) if table.clustering_keys else "[]",
            },
        )
        globals()[table_name] = dlt_table_decorator(decorated_func)

    def _register_silver_cdc_table(self, table: TableConfig) -> None:
        """Compiles Change Data Capture mappings dynamically.

        Utilizes DLT's dynamic apply_changes interface.
        """
        table_name = table.name
        source_table = table.source_table or ""
        cdc_cfg = table.cdc
        if not cdc_cfg:
            return

        # 1. Create target streaming table dynamically
        clustering_props = {}
        if table.clustering_keys:
            # Inject Liquid Clustering rules dynamically into storage options
            clustering_props["delta.clusteringkeys"] = ",".join(table.clustering_keys)

        dlt.create_streaming_table(
            name=table_name,
            comment=f"Dynamic CDC Silver Table: Merged SCD from {source_table}",
            table_properties=clustering_props,
        )

        # 2. Setup apply_changes operation at module load
        def register_cdc() -> None:
            dlt.apply_changes(
                target=table_name,
                source=source_table,
                keys=[cdc_cfg.key],
                sequence_by=cdc_cfg.sequence_by,
                stored_as_scd_type=2 if cdc_cfg.type == "SCD2" else 1,
                except_column_list=cdc_cfg.except_columns or [],
            )

        # Execute immediately on registry compilation step
        register_cdc()


def init_dynamic_pipelines(spark_session: Any, config_path: str) -> None:
    """Entrypoint function to run compilation from within the Databricks notebook."""
    compiler = DltPipelineCompiler(config_path)
    compiler.compile(spark_session)
