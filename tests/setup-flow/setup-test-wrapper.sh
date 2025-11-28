#!/bin/bash

# setup-test-wrapper.sh - Wrapper to run setup.sh in test mode
#
# This script modifies the setup.sh behavior for testing:
# - Automatically answers "yes" to DNS prompt
# - Runs all other steps normally

set -e

REPOS_DIR="/repos"
ORCHESTRATION_DIR="$REPOS_DIR/orchestration"

# Colors for output
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Setup Test Wrapper - Running setup.sh in test mode${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

cd "$ORCHESTRATION_DIR"

# Export environment variable to indicate test mode
export BA_TEST_MODE=true

# Run setup.sh with auto-yes for DNS prompt
echo "y" | "$ORCHESTRATION_DIR/setup.sh"

echo ""
echo -e "${BLUE}Setup wrapper completed${NC}"
