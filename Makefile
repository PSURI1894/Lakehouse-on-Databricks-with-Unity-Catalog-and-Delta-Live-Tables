.PHONY: install lint format test typecheck clean generate-data generate-git all

PYTHON = python
POETRY = poetry

all: format lint typecheck test

install:
	$(POETRY) install

lint:
	$(POETRY) run black --check src tests
	$(POETRY) run isort --check src tests
	$(POETRY) run flake8 src tests --max-line-length=100

format:
	$(POETRY) run black src tests
	$(POETRY) run isort src tests

typecheck:
	$(POETRY) run mypy src tests

test:
	$(POETRY) run pytest tests/ -v

generate-data:
	$(POETRY) run python scripts/data_generator.py

generate-git:
	$(PYTHON) scripts/generate_history.py

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".pytest_cache" -exec rm -rf {} +
	find . -type d -name ".mypy_cache" -exec rm -rf {} +
	rm -rf dist build *.egg-info
