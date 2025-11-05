#!/bin/bash
set -e

# Ensure proper ownership of workspace
sudo chown -R vscode:vscode /workspace 2>/dev/null || true

# Ensure .anthropic directory exists with proper permissions
if [ ! -d "/home/vscode/.anthropic" ]; then
    mkdir -p /home/vscode/.anthropic
    chmod 700 /home/vscode/.anthropic
fi

# Verify Claude Code CLI installation
if command -v claude &> /dev/null; then
    echo "✓ Claude Code CLI is installed"
    claude --version 2>/dev/null || true
else
    echo "✗ Warning: Claude Code CLI is not available"
fi

# Verify tool installations
if command -v node &> /dev/null; then
    echo "✓ Node.js $(node --version)"
else
    echo "✗ Warning: Node.js is not available"
fi

if command -v java &> /dev/null; then
    echo "✓ Java $(java --version 2>&1 | head -n 1)"
else
    echo "✗ Warning: Java is not available"
fi

if command -v mvn &> /dev/null; then
    echo "✓ Maven $(mvn --version 2>&1 | head -n 1)"
else
    echo "✗ Warning: Maven is not available"
fi

echo ""
echo "Claude Code Sandbox Environment"
echo "================================"
echo "User: vscode (UID: 1002, GID: 1002)"
echo "Workspace: /workspace (contains all projects)"
echo ""
echo "Open the Claude Code sidebar (Spark icon) to start"
echo ""

# Execute the main command
exec "$@"
