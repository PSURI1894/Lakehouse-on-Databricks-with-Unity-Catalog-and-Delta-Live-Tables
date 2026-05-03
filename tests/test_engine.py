import os
import unittest
from unittest.mock import MagicMock, patch
import pytest
import yaml
from src.dlt_engine.config_loader import PipelineConfig, load_config
from src.dlt_engine.pipeline_builder import DltPipelineCompiler


class TestLakehouseEngine(unittest.TestCase):

    def setUp(self) -> None:
        # Create a mock YAML pipeline setup for local isolated tests
        self.test_yaml = """
        pipelines:
          - name: "bronze_test"
            layer: "bronze"
            tables:
              - name: "raw_mock_orders"
                format: "cloudFiles"
                source_path: "/tmp/mock_orders/"
                cloud_files_format: "json"
                schema_evolution_mode: "addNewColumns"
        """
        self.temp_filepath = "test_pipelines_mock.yaml"
        with open(self.temp_filepath, "w") as f:
            f.write(self.test_yaml)

    def tearDown(self) -> None:
        if os.path.exists(self.temp_filepath):
            os.remove(self.temp_filepath)

    def test_config_loader(self) -> None:
        """Validates that Pydantic correctly parses and checks custom fields."""
        pipelines = load_config(self.temp_filepath)
        self.assertEqual(len(pipelines), 1)
        self.assertEqual(pipelines[0].name, "bronze_test")
        self.assertEqual(pipelines[0].layer, "bronze")
        self.assertEqual(len(pipelines[0].tables), 1)
        self.assertEqual(pipelines[0].tables[0].name, "raw_mock_orders")
        self.assertEqual(pipelines[0].tables[0].cloud_files_format, "json")

    def test_invalid_layer_validation(self) -> None:
        """Checks that invalid layers throw validation errors."""
        invalid_yaml = """
        pipelines:
          - name: "invalid_layer"
            layer: "platinum"
            tables: []
        """
        temp_invalid = "temp_invalid.yaml"
        with open(temp_invalid, "w") as f:
            f.write(invalid_yaml)

        with self.assertRaises(Exception):
            load_config(temp_invalid)

        if os.path.exists(temp_invalid):
            os.remove(temp_invalid)

    @patch("src.dlt_engine.pipeline_builder.dlt")
    def test_compiler_registration(self, mock_dlt: MagicMock) -> None:
        """Verifies DltPipelineCompiler dynamically registers tables."""
        mock_spark = MagicMock()
        compiler = DltPipelineCompiler(self.temp_filepath)

        # Execute compilation
        compiler.compile(mock_spark)

        # Check if table function was dynamically compiled and registered in globals()
        self.assertIn("raw_mock_orders", globals())
        registered_func = globals()["raw_mock_orders"]
        self.assertTrue(callable(registered_func))
