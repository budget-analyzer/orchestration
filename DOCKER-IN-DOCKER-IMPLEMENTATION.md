# Docker-in-Docker Migration Implementation

**Date**: 2025-11-26
**Plan**: /workspace/orchestration/docs/plans/docker-in-docker-migration.md

## Instructions

Exit the devcontainer, make these changes on your host machine, then rebuild.

---

## File 1: `.devcontainer/devcontainer.json`

**Action**: Add `features` section

**Current**:
```json
{
  "name": "Budget Analyzer",
  "dockerComposeFile": "../claude-code-sandbox/docker-compose.yml",
  "service": "claude-dev",
  "workspaceFolder": "/workspace/orchestration",
  "shutdownAction": "none",

  "initializeCommand": "bash ${localWorkspaceFolder}/claude-code-sandbox/setup-env.sh",

  "remoteEnv": {
    "SSH_AUTH_SOCK": ""
  },

  "customizations": {
    "vscode": {
      "extensions": [
        "anthropic.claude-code"
      ]
    }
  }
}
```

**Updated**:
```json
{
  "name": "Budget Analyzer",
  "dockerComposeFile": "../claude-code-sandbox/docker-compose.yml",
  "service": "claude-dev",
  "workspaceFolder": "/workspace/orchestration",
  "shutdownAction": "none",

  "initializeCommand": "bash ${localWorkspaceFolder}/claude-code-sandbox/setup-env.sh",

  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {
      "version": "latest",
      "moby": true
    }
  },

  "remoteEnv": {
    "SSH_AUTH_SOCK": ""
  },

  "customizations": {
    "vscode": {
      "extensions": [
        "anthropic.claude-code"
      ]
    }
  }
}
```

---

## File 2: `claude-code-sandbox/Dockerfile`

**Action**: Remove manual Docker installation (lines 42-58) and Docker GID argument (line 64, 67, 72)

**Remove this section** (lines 42-58):
```dockerfile
# Install Docker CLI (for docker-outside-of-docker pattern with Testcontainers)
#
# Note: Pinning to Docker 28.5.2 because 29.0.0 requires client version 1.44+
#       and Testcontainers uses client version 1.32.  Revisit when Testcontainers
#       releases a fix.
#
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce-cli=5:28.5.2-1~ubuntu.24.04~noble docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*
```

**Change this** (lines 60-73):
```dockerfile
# Create vscode user with matching UID/GID from host
ARG USERNAME=vscode
ARG USER_UID
ARG USER_GID
ARG DOCKER_GID

# Create docker group with host's docker GID
RUN groupadd --gid $DOCKER_GID docker || true

# Create vscode group and user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && usermod -aG docker $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
```

**To this**:
```dockerfile
# Create vscode user with matching UID/GID from host
ARG USERNAME=vscode
ARG USER_UID
ARG USER_GID

# Create vscode group and user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
```

---

## File 3: `claude-code-sandbox/docker-compose.yml`

**Action**: Remove DOCKER_GID, socket mount, and TestContainers environment variables

**Current**:
```yaml
services:
  claude-dev:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        USERNAME: vscode
        USER_UID: ${USER_UID:-1000}
        USER_GID: ${USER_GID:-1000}
        DOCKER_GID: ${DOCKER_GID:-999}

    volumes:
      # Mount dev directory as workspace (read/write)
      - ../../:/workspace:cached

      # Mount claude-code-sandbox as read-only (security: Claude Code cannot modify its own config)
      - .:/workspace/orchestration/claude-code-sandbox:ro

      # Persistent storage for Claude Code credentials
      - claude-anthropic:/home/vscode/.anthropic

      # Mount Docker socket for Testcontainers (docker-outside-of-docker pattern)
      #- /var/run/docker.sock:/var/run/docker.sock

    # Use host network for simplicity
    network_mode: host
    extra_hosts:
      - "host.docker.internal:host-gateway"  # Map to Docker host IP

    # Environment variables for Testcontainers
    environment:
      # Required for Docker Desktop compatibility (allows containers to reach host)
      - TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock
      - TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal
      - TESTCONTAINERS_REUSE_ENABLE=true

    # Keep container running
    command: sleep infinity

    user: vscode

volumes:
  claude-anthropic:
```

**Updated**:
```yaml
services:
  claude-dev:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        USERNAME: vscode
        USER_UID: ${USER_UID:-1000}
        USER_GID: ${USER_GID:-1000}

    volumes:
      # Mount dev directory as workspace (read/write)
      - ../../:/workspace:cached

      # Mount claude-code-sandbox as read-only (security: Claude Code cannot modify its own config)
      - .:/workspace/orchestration/claude-code-sandbox:ro

      # Persistent storage for Claude Code credentials
      - claude-anthropic:/home/vscode/.anthropic

    # Use host network for simplicity
    network_mode: host
    extra_hosts:
      - "host.docker.internal:host-gateway"  # Map to Docker host IP

    # Keep container running
    command: sleep infinity

    user: vscode

volumes:
  claude-anthropic:
```

---

## File 4: `claude-code-sandbox/setup-env.sh`

**Action**: Remove DOCKER_GID detection

**Current**:
```bash
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
```

**Updated**:
```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

cat > "$ENV_FILE" << EOF
# Auto-generated - do not commit
USER_UID=$CURRENT_UID
USER_GID=$CURRENT_GID
EOF

echo "✓ Generated .env in orchestration/claude-code-sandbox/"
echo "  USER_UID=$CURRENT_UID"
echo "  USER_GID=$CURRENT_GID"
```

---

## After Making Changes

1. **Exit devcontainer**: Close VS Code or exit the devcontainer
2. **Rebuild**: In VS Code, run "Dev Containers: Rebuild Container"
3. **First build will be slower**: Downloads docker-in-docker feature image
4. **Verify**:
   ```bash
   docker ps  # Should work inside container
   docker info  # Should show separate daemon
   ```

## Testing

After rebuild:
- Run `docker ps` inside container - should work
- Run integration tests with TestContainers - should pass
- Run `docker ps` on host vs container - should show different containers (isolation verified)

## Rollback

If issues occur, revert commits and uncomment socket mount in docker-compose.yml line 23.

## Security Improvement

**Before**: Docker socket mount = container can access host's Docker daemon = full host access
**After**: Docker-in-Docker = container has its own isolated daemon = host protected

See plan document for full security analysis.
