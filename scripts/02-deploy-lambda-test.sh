#!/bin/bash
# ============================================================
# 02-deploy-lambda-test.sh — Deploy Lambda + Version + Alias test
# ============================================================
set -euo pipefail

echo "🟢 [Pipeline 2] Deploying Lambda function..."

FUNCTION_NAME="cuentas-lambda-${SUFFIX}"
ALIAS_NAME="test"
ZIP_FILE="/tmp/function.zip"

# ── Step 1: Package Lambda code ──
echo "📌 Packaging Lambda function..."
cd implementation
zip -r "$ZIP_FILE" src/
cd ..

# ── Step 2: Create or Update Lambda function ──
echo "📌 Checking if function '${FUNCTION_NAME}' exists..."
if aws lambda get-function --function-name "$FUNCTION_NAME" --no-cli-pager 2>/dev/null; then
  echo "♻️  Function exists. Updating code..."
  aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file "fileb://${ZIP_FILE}" \
    --no-cli-pager

  echo "⏳ Waiting for function update..."
  aws lambda wait function-updated-v2 --function-name "$FUNCTION_NAME"
else
  echo "🆕 Creating new Lambda function..."
  aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime nodejs20.x \
    --handler src/index.handler \
    --role "$LAMBDA_ROLE_ARN" \
    --zip-file "fileb://${ZIP_FILE}" \
    --timeout 10 \
    --memory-size 128 \
    --no-cli-pager

  echo "⏳ Waiting for function to be active..."
  aws lambda wait function-active-v2 --function-name "$FUNCTION_NAME"
fi

# ── Step 3: Publish a new version ──
echo "📌 Publishing new version..."
VERSION=$(aws lambda publish-version \
  --function-name "$FUNCTION_NAME" \
  --description "Deployed from pipeline" \
  --query 'Version' --output text \
  --no-cli-pager)

echo "✅ Published version: ${VERSION}"

# ── Step 4: Create or update alias 'test' ──
echo "📌 Configuring alias '${ALIAS_NAME}' → version ${VERSION}..."
if aws lambda get-alias --function-name "$FUNCTION_NAME" --name "$ALIAS_NAME" --no-cli-pager 2>/dev/null; then
  aws lambda update-alias \
    --function-name "$FUNCTION_NAME" \
    --name "$ALIAS_NAME" \
    --function-version "$VERSION" \
    --no-cli-pager
else
  aws lambda create-alias \
    --function-name "$FUNCTION_NAME" \
    --name "$ALIAS_NAME" \
    --function-version "$VERSION" \
    --no-cli-pager
fi

echo "✅ Alias '${ALIAS_NAME}' → version ${VERSION}"

# ── Step 5: Export for next steps ──
echo "LAMBDA_VERSION=${VERSION}" >> "$GITHUB_ENV" 2>/dev/null || true
echo "FUNCTION_NAME=${FUNCTION_NAME}" >> "$GITHUB_ENV" 2>/dev/null || true

echo "🟢 [Pipeline 2] Lambda deployment completed successfully!"
