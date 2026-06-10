#!/bin/bash
# ============================================================
# 03-update-api-integration.sh — Update API GW: mock → Lambda
# ============================================================
set -euo pipefail

echo "🟢 [Pipeline 2] Updating API Gateway integration to Lambda..."

API_NAME="cuentas-api-${SUFFIX}"
FUNCTION_NAME="cuentas-lambda-${SUFFIX}"
ALIAS_NAME="test"
STAGE_NAME="test"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# ── Step 1: Get API ID ──
API_ID=$(aws apigateway get-rest-apis --limit 500 \
  --query "items[?name=='${API_NAME}'].id" \
  --output text --no-cli-pager)

if [ -z "$API_ID" ] || [ "$API_ID" == "None" ]; then
  echo "❌ Error: Could not find API ID for name ${API_NAME}"
  exit 1
fi

echo "📌 API ID: ${API_ID}"

# ── Step 2: Get resource ID for /clientes/{clienteId}/cuentas ──
RESOURCES=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --query 'items' --output json --no-cli-pager)

RESOURCE_ID=$(echo "$RESOURCES" | python3 -c "
import sys, json
items = json.load(sys.stdin)
for item in items:
    if 'cuentas' in item.get('path', ''):
        print(item['id'])
        break
")

echo "📌 Resource ID: ${RESOURCE_ID}"

# ── Step 3: Update integration to Lambda proxy ──
LAMBDA_URI="arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${ACCOUNT_ID}:function:${FUNCTION_NAME}:${ALIAS_NAME}/invocations"

echo "📌 Setting integration to Lambda alias '${ALIAS_NAME}'..."
aws apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$RESOURCE_ID" \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "$LAMBDA_URI" \
  --no-cli-pager

# ── Step 4: Add Lambda permission for API Gateway ──
echo "📌 Adding Lambda invoke permission for API Gateway..."
aws lambda add-permission \
  --function-name "${FUNCTION_NAME}:${ALIAS_NAME}" \
  --statement-id "apigateway-test-${SUFFIX}" \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${AWS_REGION}:${ACCOUNT_ID}:${API_ID}/*/GET/clientes/*/cuentas" \
  --no-cli-pager 2>/dev/null || echo "⚠️  Permission already exists (OK)"

# ── Step 5: Re-deploy stage test ──
echo "📌 Re-deploying stage '${STAGE_NAME}'..."
aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE_NAME" \
  --description "Lambda integration deployment" \
  --no-cli-pager

# ── Step 6: Export OpenAPI (now with Lambda integration) ──
echo "📌 Exporting updated OpenAPI spec..."
aws apigateway get-export \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE_NAME" \
  --export-type oas30 \
  --accepts application/json \
  --no-cli-pager \
  /tmp/openapi-export.json

echo "✅ API Gateway now points to Lambda alias '${ALIAS_NAME}'"
echo "🟢 [Pipeline 2] API Gateway update completed!"
