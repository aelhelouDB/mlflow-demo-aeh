#!/bin/bash
# Deploy the Lakehouse App.
# For configuration options see README.md and .env.local.

set -e

# Parse command line arguments
SYNC_ONLY=false
for arg in "$@"; do
  case $arg in
    --sync-only)
      SYNC_ONLY=true
      shift
      ;;
    *)
      # Unknown option
      echo "Unknown option: $arg"
      echo "Usage: $0 [--sync-only]"
      echo "  --sync-only    Sync notebooks only, skip app deployment"
      exit 1
      ;;
  esac
done

# Load environment variables from .env.local if it exists.
if [ -f .env.local ]
then
  set -a
  source .env.local
  set +a
fi

# If LHA_SOURCE_CODE_PATH is not set throw an error.
if [ -z "$LHA_SOURCE_CODE_PATH" ]
then
  echo "LHA_SOURCE_CODE_PATH is not set. Please set to the /Workspace/Users/{username}/{lha-name} in .env.local."
  exit 1
fi

if [ -z "$DATABRICKS_APP_NAME" ]
then
  echo "DATABRICKS_APP_NAME is not set. Please set to the name of the app in .env.local."
  exit 1
fi

if [ -z "$DATABRICKS_CONFIG_PROFILE" ]
then
  DATABRICKS_CONFIG_PROFILE="DEFAULT"
fi

mkdir -p client/build

# Generate requirements.txt from pyproject.toml preserving version ranges
uv run python scripts/generate_semver_requirements.py



# Backup current app.yaml and use template
mv app.yaml app.yaml.previous
cp app.yaml.template app.yaml

# Update app.yaml with MLFLOW_EXPERIMENT_ID from .env.local
if [ -n "$MLFLOW_EXPERIMENT_ID" ]; then
  echo "🔧 Setting MLFLOW_EXPERIMENT_ID to $MLFLOW_EXPERIMENT_ID in app.yaml..."
  sed -i.bak "s|value: 'your-experiment-id'|value: '$MLFLOW_EXPERIMENT_ID'|" app.yaml
  rm -f app.yaml.bak
else
  echo "⚠️  MLFLOW_EXPERIMENT_ID not found in environment"
fi

# Update app.yaml with evaluation result URLs from .env.local
if [ -n "$LOW_ACCURACY_RESULTS_URL" ]; then
  echo "🔧 Setting LOW_ACCURACY_RESULTS_URL in app.yaml..."
  ESCAPED_URL=$(echo "$LOW_ACCURACY_RESULTS_URL" | sed 's/&/\\&/g')
  sed -i.bak "s|value: 'placeholder-low-accuracy-url'|value: '$ESCAPED_URL'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$REGRESSION_RESULTS_URL" ]; then
  echo "🔧 Setting REGRESSION_RESULTS_URL in app.yaml..."
  ESCAPED_URL=$(echo "$REGRESSION_RESULTS_URL" | sed 's/&/\\&/g')
  sed -i.bak "s|value: 'placeholder-regression-url'|value: '$ESCAPED_URL'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$METRICS_RESULT_URL" ]; then
  echo "🔧 Setting METRICS_RESULT_URL in app.yaml..."
  ESCAPED_URL=$(echo "$METRICS_RESULT_URL" | sed 's/&/\\&/g')
  sed -i.bak "s|value: 'placeholder-metrics-url'|value: '$ESCAPED_URL'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$LHA_SOURCE_CODE_PATH" ]; then
  echo "🔧 Setting LHA_SOURCE_CODE_PATH in app.yaml..."
  ESCAPED_PATH=$(echo "$LHA_SOURCE_CODE_PATH" | sed 's/&/\\&/g')
  sed -i.bak "s|value: 'placeholder-lha-source-code-path'|value: '$ESCAPED_PATH'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$LLM_MODEL" ]; then
  echo "🔧 Setting LLM_MODEL to $LLM_MODEL in app.yaml..."
  sed -i.bak "s|value: 'placeholder-llm-model'|value: '$LLM_MODEL'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$UC_CATALOG" ]; then
  echo "🔧 Setting UC_CATALOG to $UC_CATALOG in app.yaml..."
  sed -i.bak "s|value: 'placeholder-uc-catalog'|value: '$UC_CATALOG'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$UC_SCHEMA" ]; then
  echo "🔧 Setting UC_SCHEMA to $UC_SCHEMA in app.yaml..."
  sed -i.bak "s|value: 'placeholder-uc-schema'|value: '$UC_SCHEMA'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$MLFLOW_ENABLE_ASYNC_TRACE_LOGGING" ]; then
  echo "🔧 Setting MLFLOW_ENABLE_ASYNC_TRACE_LOGGING to $MLFLOW_ENABLE_ASYNC_TRACE_LOGGING in app.yaml..."
  sed -i.bak "s|value: 'placeholder-async-logging'|value: '$MLFLOW_ENABLE_ASYNC_TRACE_LOGGING'|" app.yaml
  rm -f app.yaml.bak
fi

# Compute MLFLOW_TRACING_DESTINATION from UC_CATALOG and UC_SCHEMA
if [ -n "$UC_CATALOG" ] && [ -n "$UC_SCHEMA" ]; then
  MLFLOW_TRACING_DESTINATION="${UC_CATALOG}.${UC_SCHEMA}"
  echo "🔧 Setting MLFLOW_TRACING_DESTINATION to $MLFLOW_TRACING_DESTINATION in app.yaml..."
  sed -i.bak "s|value: 'placeholder-tracing-destination'|value: '$MLFLOW_TRACING_DESTINATION'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$SQL_WAREHOUSE_ID" ]; then
  echo "🔧 Setting SQL_WAREHOUSE_ID to $SQL_WAREHOUSE_ID in app.yaml..."
  sed -i.bak "s|value: 'placeholder-sql-warehouse-id'|value: '$SQL_WAREHOUSE_ID'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$PROMPT_NAME" ]; then
  echo "🔧 Setting PROMPT_NAME to $PROMPT_NAME in app.yaml..."
  sed -i.bak "s|value: 'placeholder-prompt-name'|value: '$PROMPT_NAME'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$SAMPLE_LABELING_SESSION_ID" ]; then
  echo "🔧 Setting SAMPLE_LABELING_SESSION_ID to $SAMPLE_LABELING_SESSION_ID in app.yaml..."
  sed -i.bak "s|value: 'placeholder-sample-labeling-session-id'|value: '$SAMPLE_LABELING_SESSION_ID'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$SAMPLE_REVIEW_APP_URL" ]; then
  echo "🔧 Setting SAMPLE_REVIEW_APP_URL to $SAMPLE_REVIEW_APP_URL in app.yaml..."
  ESCAPED_URL=$(echo "$SAMPLE_REVIEW_APP_URL" | sed 's/&/\\&/g')
  sed -i.bak "s|value: 'placeholder-sample-review-app-url'|value: '$ESCAPED_URL'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$SAMPLE_LABELING_TRACE_ID" ]; then
  echo "🔧 Setting SAMPLE_LABELING_TRACE_ID to $SAMPLE_LABELING_TRACE_ID in app.yaml..."
  sed -i.bak "s|value: 'placeholder-sample-labeling-trace-id'|value: '$SAMPLE_LABELING_TRACE_ID'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$SAMPLE_TRACE_ID" ]; then
  echo "🔧 Setting SAMPLE_TRACE_ID to $SAMPLE_TRACE_ID in app.yaml..."
  sed -i.bak "s|value: 'placeholder-sample-trace-id'|value: '$SAMPLE_TRACE_ID'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$PROMPT_ALIAS" ]; then
  echo "🔧 Setting PROMPT_ALIAS to $PROMPT_ALIAS in app.yaml..."
  sed -i.bak "s|value: 'placeholder-prompt-alias'|value: '$PROMPT_ALIAS'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$REGRESSION_BASELINE_RUN_ID" ]; then
  echo "🔧 Setting REGRESSION_BASELINE_RUN_ID to $REGRESSION_BASELINE_RUN_ID in app.yaml..."
  sed -i.bak "s|value: 'placeholder-regression-baseline-run-id'|value: '$REGRESSION_BASELINE_RUN_ID'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$FIX_QUALITY_BASELINE_RUN_ID" ]; then
  echo "🔧 Setting FIX_QUALITY_BASELINE_RUN_ID to $FIX_QUALITY_BASELINE_RUN_ID in app.yaml..."
  sed -i.bak "s|value: 'placeholder-fix-quality-baseline-run-id'|value: '$FIX_QUALITY_BASELINE_RUN_ID'|" app.yaml
  rm -f app.yaml.bak
fi

# Build fastapi client.
uv run python -m scripts.make_fastapi_client

# Build javascript.
pushd client && BROWSER=none npm run build && popd

databricks sync . "$LHA_SOURCE_CODE_PATH" \
  --profile "$DATABRICKS_CONFIG_PROFILE" \
  --exclude "*.gif"

# Generate notebook URLs and save to .env.local
uv run python scripts/generate_notebook_urls.py

# Source .env.local to get the notebook URLs
set -a
source .env.local
set +a

# Substitute notebook URLs in app.yaml
if [ -n "$NOTEBOOK_URL_0_demo_overview" ]; then
  echo "🔧 Setting NOTEBOOK_URL_0_demo_overview to $NOTEBOOK_URL_0_demo_overview in app.yaml..."
  sed -i.bak "s|value: 'placeholder-notebook-url-0'|value: '$NOTEBOOK_URL_0_demo_overview'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$NOTEBOOK_URL_1_observe_with_traces" ]; then
  echo "🔧 Setting NOTEBOOK_URL_1_observe_with_traces to $NOTEBOOK_URL_1_observe_with_traces in app.yaml..."
  sed -i.bak "s|value: 'placeholder-notebook-url-1'|value: '$NOTEBOOK_URL_1_observe_with_traces'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$NOTEBOOK_URL_2_create_quality_metrics" ]; then
  echo "🔧 Setting NOTEBOOK_URL_2_create_quality_metrics to $NOTEBOOK_URL_2_create_quality_metrics in app.yaml..."
  sed -i.bak "s|value: 'placeholder-notebook-url-2'|value: '$NOTEBOOK_URL_2_create_quality_metrics'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$NOTEBOOK_URL_3_find_fix_quality_issues" ]; then
  echo "🔧 Setting NOTEBOOK_URL_3_find_fix_quality_issues to $NOTEBOOK_URL_3_find_fix_quality_issues in app.yaml..."
  sed -i.bak "s|value: 'placeholder-notebook-url-3'|value: '$NOTEBOOK_URL_3_find_fix_quality_issues'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$NOTEBOOK_URL_4_human_review" ]; then
  echo "🔧 Setting NOTEBOOK_URL_4_human_review to $NOTEBOOK_URL_4_human_review in app.yaml..."
  sed -i.bak "s|value: 'placeholder-notebook-url-4'|value: '$NOTEBOOK_URL_4_human_review'|" app.yaml
  rm -f app.yaml.bak
fi

if [ -n "$NOTEBOOK_URL_5_production_monitoring" ]; then
  echo "🔧 Setting NOTEBOOK_URL_5_production_monitoring to $NOTEBOOK_URL_5_production_monitoring in app.yaml..."
  sed -i.bak "s|value: 'placeholder-notebook-url-5'|value: '$NOTEBOOK_URL_5_production_monitoring'|" app.yaml
  rm -f app.yaml.bak
fi

databricks sync . "$LHA_SOURCE_CODE_PATH" \
  --profile "$DATABRICKS_CONFIG_PROFILE" \
  --exclude "*.gif"

# Skip app deployment if --sync-only flag is set
if [ "$SYNC_ONLY" = true ]; then
  echo ""
  echo "📓 Notebook sync completed (--sync-only mode)!"
  echo "✅ Notebooks synced to workspace: $LHA_SOURCE_CODE_PATH"
  echo ""
  exit 0
fi

databricks apps deploy $DATABRICKS_APP_NAME \
  --source-code-path "$LHA_SOURCE_CODE_PATH"\
  --profile "$DATABRICKS_CONFIG_PROFILE"

echo ""
echo "🎉 Deployment completed!"
echo ""

# Grant UC permissions to the app's service principal
if [ -n "$UC_CATALOG" ] && [ -n "$UC_SCHEMA" ]; then
  echo "🔐 Granting UC permissions to app service principal..."
  uv run python -c "
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.ml import ExperimentAccessControlRequest, ExperimentPermissionLevel
import os

w = WorkspaceClient()
app_name = os.environ['DATABRICKS_APP_NAME']
catalog = os.environ['UC_CATALOG']
schema = os.environ['UC_SCHEMA']
warehouse_id = os.environ.get('SQL_WAREHOUSE_ID')
experiment_id = os.environ.get('MLFLOW_EXPERIMENT_ID')

# Get the app's service principal
app = w.apps.get(app_name)
sp_name = getattr(app, 'service_principal_name', None)
sp_client_id = getattr(app, 'service_principal_client_id', None)
if not sp_name and not sp_client_id:
    print('⚠️  Could not find service principal for app, skipping grants')
    exit(0)

principal = sp_client_id or sp_name
print(f'   App service principal: {sp_name} (client_id: {sp_client_id})')

# --- UC Catalog & Schema Grants ---
if warehouse_id:
    # Use SQL GRANT statements (more reliable than SDK grants.update which has enum serialization issues)
    # Prompts are stored as UC functions, so the SP needs explicit function-level privileges
    grants = [
        f'GRANT USE CATALOG ON CATALOG \`{catalog}\` TO \`{principal}\`',
        f'GRANT USE SCHEMA ON SCHEMA \`{catalog}\`.\`{schema}\` TO \`{principal}\`',
        f'GRANT CREATE FUNCTION ON SCHEMA \`{catalog}\`.\`{schema}\` TO \`{principal}\`',
        f'GRANT EXECUTE ON SCHEMA \`{catalog}\`.\`{schema}\` TO \`{principal}\`',
        f'GRANT MANAGE ON SCHEMA \`{catalog}\`.\`{schema}\` TO \`{principal}\`',
    ]
    for sql in grants:
        try:
            result = w.statement_execution.execute_statement(
                warehouse_id=warehouse_id, statement=sql, wait_timeout='30s',
            )
            state = result.status.state.value if result.status and result.status.state else 'UNKNOWN'
            if state == 'SUCCEEDED':
                target = sql.split(' ON ')[1].split(' TO ')[0]
                print(f'   ✅ Granted {target}')
            else:
                error_msg = getattr(result.status, 'error', None)
                print(f'   ⚠️  Grant returned {state}: {error_msg}')
        except Exception as e:
            print(f'   ⚠️  SQL grant failed: {e}')
else:
    # Fallback to SDK grants API with string securable types
    # Prompts are stored as UC functions, so the SP needs explicit function-level privileges
    from databricks.sdk.service.catalog import PermissionsChange, Privilege
    sdk_grants = [
        ('catalog', catalog, [Privilege.USE_CATALOG]),
        ('schema', f'{catalog}.{schema}', [Privilege.USE_SCHEMA, Privilege.CREATE_FUNCTION, Privilege.EXECUTE, Privilege.MANAGE]),
    ]
    for securable_type, full_name, privileges in sdk_grants:
        try:
            w.grants.update(
                securable_type=securable_type,
                full_name=full_name,
                changes=[PermissionsChange(add=privileges, principal=principal)],
            )
            priv_names = [p.value for p in privileges]
            print(f'   ✅ Granted {priv_names} on {securable_type} {full_name}')
        except Exception as e:
            print(f'   ⚠️  {securable_type} grant failed: {e}')

# --- MLflow Experiment Permission ---
# CAN_MANAGE is required for the app SP to load/update prompts in the prompt registry
if experiment_id:
    try:
        w.experiments.set_permissions(
            experiment_id=experiment_id,
            access_control_list=[
                ExperimentAccessControlRequest(
                    service_principal_name=principal,
                    permission_level=ExperimentPermissionLevel.CAN_MANAGE,
                ),
            ],
        )
        print(f'   ✅ Granted CAN_MANAGE on experiment {experiment_id}')
    except Exception as e:
        print(f'   ⚠️  Experiment permission grant failed: {e}')
else:
    print('   ⚠️  MLFLOW_EXPERIMENT_ID not set, skipping experiment permissions')

print('🔐 Permission grants complete')
" || echo "⚠️  Permission grant step failed (non-blocking)"
fi

# Get app status and URL
echo "📊 Checking app status..."
APP_STATUS=$(databricks apps list --profile "$DATABRICKS_CONFIG_PROFILE" | grep "$DATABRICKS_APP_NAME" || echo "")

if [ -n "$APP_STATUS" ]; then
  echo "✅ App found in Databricks Apps list"
  echo "$APP_STATUS"
  echo ""

  # Wait a moment for app to start up
  echo "⏳ Waiting for app to start up..."
  sleep 10

  # Attempt to get app URL and test health endpoint
  echo "🔍 Testing app health..."

  # Note: You'll need to replace this with your actual app URL pattern
  # This is a placeholder that would need to be customized based on your Databricks setup
  echo "📋 Post-deployment checklist:"
  echo ""
  echo "🔗 App Access:"
  echo "  • Navigate to Compute → Apps in your Databricks workspace"
  echo "  • Click on '$DATABRICKS_APP_NAME' to access your app"
  echo "  • Test the chat interface to verify agent functionality"
  echo ""
  echo "📊 Monitoring Setup:"
  echo "  • App Logs: Click 'Logs' tab in your app overview"
  echo "  • Direct Log Access: Add /logz to your app URL"
  echo "  • Health Check: Add /api/health to your app URL"
  echo "  • MLflow Traces: Check experiment ID $MLFLOW_EXPERIMENT_ID"
  echo ""
  echo "🧪 Verification Steps:"
  echo "  1. Send a test message in the chat interface"
  echo "  2. Verify logs appear in the Logs tab"
  echo "  3. Check MLflow experiment for new traces"
  echo "  4. Test thumbs up/down feedback functionality"
  echo ""
  echo "🚨 Troubleshooting:"
  echo "  • If app won't start: Check Environment tab for errors"
  echo "  • If no logs: Verify app writes to stdout/stderr"
  echo "  • If MLflow issues: Check MLFLOW_EXPERIMENT_ID in Environment"
  echo ""
else
  echo "⚠️  App not found in apps list - deployment may have failed"
  echo ""
  echo "🔧 Debugging steps:"
  echo "  1. Run: databricks apps list --profile $DATABRICKS_CONFIG_PROFILE"
  echo "  2. Check your .env.local file for correct DATABRICKS_APP_NAME"
  echo "  3. Verify workspace permissions for app deployment"
  echo "  4. Check app.yaml configuration file"
fi
