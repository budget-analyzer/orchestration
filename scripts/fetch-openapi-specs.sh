#!/bin/bash
set -e

# Fetch OpenAPI specs from running services and write to their repos
# Assumes services are running on their configured ports

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"

# Service configurations: name, port, context-path, repo-path
SERVICES=(
  "transaction-service:8082:transaction-service:../transaction-service"
  "currency-service:8084:currency-service:../currency-service"
)

echo "Fetching OpenAPI specifications from running services..."
echo

SUCCESS=0
FAILED=0
MISSING_REPO=0

for SERVICE_CONFIG in "${SERVICES[@]}"; do
  IFS=':' read -r SERVICE_NAME PORT CONTEXT_PATH REPO_PATH <<< "$SERVICE_CONFIG"

  URL="http://localhost:${PORT}/${CONTEXT_PATH}/v3/api-docs.yaml"
  OUTPUT_DIR="${WORKSPACE_DIR}/${REPO_PATH}/docs/api"
  OUTPUT_FILE="${OUTPUT_DIR}/openapi.yaml"

  echo "📡 Fetching ${SERVICE_NAME}..."
  echo "   URL: ${URL}"

  # Check if repo exists
  if [ ! -d "${WORKSPACE_DIR}/${REPO_PATH}" ]; then
    echo "   ⚠️  Repository not found at ${REPO_PATH}"
    MISSING_REPO=$((MISSING_REPO + 1))
    echo
    continue
  fi

  # Create output directory if it doesn't exist
  mkdir -p "${OUTPUT_DIR}"

  # Fetch the OpenAPI spec as YAML
  if curl -f -s "${URL}" -o "${OUTPUT_FILE}" 2>/dev/null; then
    echo "   ✅ Saved to ${REPO_PATH}/docs/api/openapi.yaml"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "   ❌ Failed to fetch (service may not be running)"
    FAILED=$((FAILED + 1))
  fi

  echo
done

echo "Summary:"
echo "  ✅ Successfully fetched: ${SUCCESS}"
[ $FAILED -gt 0 ] && echo "  ❌ Failed to fetch: ${FAILED}"
[ $MISSING_REPO -gt 0 ] && echo "  ⚠️  Repositories not found: ${MISSING_REPO}"

if [ $FAILED -gt 0 ]; then
  echo
  echo "Make sure services are running: docker compose up -d"
  exit 1
fi

if [ $MISSING_REPO -gt 0 ]; then
  echo
  echo "Clone missing repositories to the parent directory of orchestration/"
  exit 1
fi

exit 0
