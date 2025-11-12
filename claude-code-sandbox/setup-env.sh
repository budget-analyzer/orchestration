#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)
DOCKER_GROUP_ID=$(getent group docker 2>/dev/null | cut -d: -f3 || echo 999)

cat > "$ENV_FILE" << EOF
# Auto-generated - do not commit
USER_UID=$CURRENT_UID
USER_GID=$CURRENT_GID
DOCKER_GID=$DOCKER_GROUP_ID
EOF

echo "✓ Generated .env in orchestration/claude-code-sandbox/"
echo "  USER_UID=$CURRENT_UID"
echo "  USER_GID=$CURRENT_GID"
echo "  DOCKER_GID=$DOCKER_GROUP_ID"