import os
from typing import Dict, List, Optional

import yaml
from pydantic import BaseModel, Field, field_validator


class TableTag(BaseModel):
    pii: Optional[str] = None
    retention: Optional[str] = None
    classification: Optional[str] = None


class ExpectationDetail(BaseModel):
    expr: str
    action: str

    @field_validator("action")
    @classmethod
    def validate_action(cls, v: str) -> str:
        allowed = {"WARN", "DROP", "FAIL"}
        if v.upper() not in allowed:
            raise ValueError(f"Action must be one of {allowed}, got {v}")
        return v.upper()


class CDCConfig(BaseModel):
    enabled: bool = False
    type: str = "SCD1"
    key: str
    sequence_by: str
    except_columns: Optional[List[str]] = None

    @field_validator("type")
    @classmethod
    def validate_cdc_type(cls, v: str) -> str:
        allowed = {"SCD1", "SCD2"}
        if v.upper() not in allowed:
            raise ValueError(f"CDC Type must be SCD1 or SCD2, got {v}")
        return v.upper()


class TableConfig(BaseModel):
    name: str
    format: Optional[str] = None
    source_path: Optional[str] = None
    source_table: Optional[str] = None
    cloud_files_format: Optional[str] = None
    csv_header: Optional[bool] = None
    schema_evolution_mode: Optional[str] = None
    watermark: Optional[str] = None
    expectations: Optional[Dict[str, ExpectationDetail]] = None
    cdc: Optional[CDCConfig] = None
    clustering_keys: Optional[List[str]] = None
    tags: Optional[TableTag] = None


class PipelineConfig(BaseModel):
    name: str
    layer: str
    tables: List[TableConfig]

    @field_validator("layer")
    @classmethod
    def validate_layer(cls, v: str) -> str:
        allowed = {"bronze", "silver", "gold"}
        if v.lower() not in allowed:
            raise ValueError(f"Layer must be bronze, silver or gold, got {v}")
        return v.lower()


class LakehouseConfig(BaseModel):
    pipelines: List[PipelineConfig]


def load_config(config_path: str) -> List[PipelineConfig]:
    """Loads and validates the pipelines metadata YAML configuration."""
    if not os.path.exists(config_path):
        raise FileNotFoundError(f"Configuration file not found: {config_path}")

    with open(config_path, "r") as f:
        raw_data = yaml.safe_load(f)

    validated = LakehouseConfig(**raw_data)
    return validated.pipelines
