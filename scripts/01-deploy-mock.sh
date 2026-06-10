#!/bin/bash
# ============================================================
# 01-deploy-mock.sh — Deploy API Gateway con integración Mock
# ============================================================
set -euo pipefail

echo "🔵 [Pipeline 1] Deploying API Gateway with Mock integration..."

API_NAME="cuentas-api-${SUFFIX}"
STAGE_NAME="test"
OPENAPI_FILE="contract/openapi.yaml"

# ── Step 1: Verificar si ya existe la API ──
echo "📌 Checking if API '${API_NAME}' already exists..."
EXISTING_API_ID=$(aws apigateway get-rest-apis --query "items[?name=='${API_NAME}'].id" --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_API_ID" ] && [ "$EXISTING_API_ID" != "None" ]; then
  echo "♻️  API already exists (ID: ${EXISTING_API_ID}). Updating..."
  aws apigateway put-rest-api \
    --rest-api-id "$EXISTING_API_ID" \
    --mode overwrite \
    --body "fileb://${OPENAPI_FILE}" \
    --no-cli-pager
  API_ID="$EXISTING_API_ID"
else
  echo "🆕 Creating new REST API..."
  API_ID=$(aws apigateway import-rest-api \
    --body "fileb://${OPENAPI_FILE}" \
    --parameters endpointConfigurationTypes=REGIONAL \
    --query 'id' --output text \
    --no-cli-pager)

  # Rename API
  aws apigateway update-rest-api \
    --rest-api-id "$API_ID" \
    --patch-operations op=replace,path=/name,value="${API_NAME}" \
    --no-cli-pager
fi

echo "✅ API ID: ${API_ID}"

# ── Step 2: Deploy to stage test ──
echo "📌 Deploying to stage '${STAGE_NAME}'..."
aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE_NAME" \
  --description "Mock deployment from pipeline" \
  --no-cli-pager

ENDPOINT="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/${STAGE_NAME}"
echo "✅ Mock deployed at: ${ENDPOINT}"

# ── Step 3: Export API ID for next steps ──
echo "API_ID=${API_ID}" >> "$GITHUB_ENV" 2>/dev/null || true
echo "API_ENDPOINT=${ENDPOINT}" >> "$GITHUB_ENV" 2>/dev/null || true

# ── Step 4: Export OpenAPI from API Gateway ──
echo "📌 Exporting OpenAPI spec from API Gateway..."
aws apigateway get-export \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE_NAME" \
  --export-type oas30 \
  --accepts application/json \
  --no-cli-pager \
  /tmp/openapi-export.json

echo "✅ OpenAPI exported to /tmp/openapi-export.json"
echo "🔵 [Pipeline 1] Mock deployment completed successfully!"
