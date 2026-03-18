# Databricks notebook source
# =====================================================================
# DYNAMIC METADATA-DRIVEN PIPELINE EXECUTION WRAPPER
# Compiles pipeline declarations dynamically within the DLT context.
# =====================================================================

# COMMAND ----------
import sys
import os

# COMMAND ----------
# Inject workspace package source paths to ensure absolute imports resolve
workspace_root = "/Workspace" + os.path.dirname(os.path.dirname(os.path.abspath(dbutils.notebook.entry_point.getDbutils().notebook().getContext().notebookPath().get())))
sys.path.append(workspace_root)

# COMMAND ----------
from src.dlt_engine.pipeline_builder import init_dynamic_pipelines

# COMMAND ----------
# Retrieve configuration paths from Databricks Job parameters or fallback to default
config_path = dbutils.widgets.getArgument("config_path")
if not config_path:
    # Default fallback path in Unity Catalog workspace
    config_path = "/dbfs/Shared/metadata/pipelines.yaml"

# COMMAND ----------
# Run dynamic compilation to register DLT tables in current context
init_dynamic_pipelines(spark, config_path)
