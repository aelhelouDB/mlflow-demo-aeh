import sys
from pathlib import Path

# Add the project root to Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

import dotenv

# Load environment variables from .env.local in project root
dotenv.load_dotenv(project_root / '.env.local')

# allow databricks-cli auth to take over (remove token so profile/CLI auth is used,
# but keep DATABRICKS_HOST so MLflow can resolve the 'databricks' tracking URI)
import os
os.environ.pop('DATABRICKS_TOKEN', None)

# MLflow requires MLFLOW_TRACING_SQL_WAREHOUSE_ID when writing traces to UC-backed experiments.
# Bridge from SQL_WAREHOUSE_ID if not explicitly set.
if not os.environ.get('MLFLOW_TRACING_SQL_WAREHOUSE_ID') and os.environ.get('SQL_WAREHOUSE_ID'):
  os.environ['MLFLOW_TRACING_SQL_WAREHOUSE_ID'] = os.environ['SQL_WAREHOUSE_ID']



from mlflow_demo.evaluation.evaluator import SCORERS
from mlflow.genai.scorers import ScorerSamplingConfig
from mlflow.genai.scorers import get_scorer, delete_scorer

# UNCOMMENT THIS

import logging
logging.getLogger("urllib3").setLevel(logging.ERROR)
logging.getLogger("mlflow").setLevel(logging.ERROR)


import mlflow
from mlflow.entities import UCSchemaLocation
from mlflow.tracing import set_databricks_monitoring_sql_warehouse_id


# Unity Catalog schema to store the prompt in
UC_CATALOG = os.environ.get('UC_CATALOG')
UC_SCHEMA = os.environ.get('UC_SCHEMA')
SQL_WAREHOUSE_ID = os.environ.get('SQL_WAREHOUSE_ID')
MLFLOW_EXPERIMENT_ID = os.environ.get('MLFLOW_EXPERIMENT_ID')
# Exit if required environment variables are not set
if not UC_CATALOG or not UC_SCHEMA:
  print('Error: UC_CATALOG and UC_SCHEMA environment variables must be set')
  sys.exit(1)

# Set tracing destination to UC so scorers can write to UC tables
mlflow.set_tracking_uri('databricks')
mlflow.tracing.set_destination(
  destination=UCSchemaLocation(catalog_name=UC_CATALOG, schema_name=UC_SCHEMA)
)
print(f'✅ Tracing destination set to UC: {UC_CATALOG}.{UC_SCHEMA}')

# Enable production monitoring with SQL warehouse
if SQL_WAREHOUSE_ID and MLFLOW_EXPERIMENT_ID:
  set_databricks_monitoring_sql_warehouse_id(
    sql_warehouse_id=SQL_WAREHOUSE_ID,
    experiment_id=MLFLOW_EXPERIMENT_ID,
  )
  print(f'✅ Production monitoring enabled with SQL warehouse: {SQL_WAREHOUSE_ID}')
else:
  print('⚠️  SQL_WAREHOUSE_ID or MLFLOW_EXPERIMENT_ID not set, skipping monitoring setup')

for scorer in SCORERS:
  # Register each scorer with MLflow
  try:
    scorer.register()
  except Exception as e:
    print(f'⚠️ Warning: Scorer {scorer.name} registration failed or already exists: {e}')
    print('   Attempting to re-register by deleting existing scorer...')
    delete_scorer(name=scorer.name)
    scorer.register()

  scorer.start(sampling_config=ScorerSamplingConfig(sample_rate=1))



