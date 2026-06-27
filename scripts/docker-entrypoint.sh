#!/bin/sh
set -e
# Capture runtime UID/GID from environment variables, defaulting to 1000
PUID=${USER_UID:-1000}
PGID=${USER_GID:-1000}

# Set up Composio CLI and codex MCP config
if [ -n "$COMPOSIO_API_KEY" ]; then
    apt-get update -qq && apt-get install -y -qq unzip > /dev/null 2>&1 || true
    curl -fsSL https://composio.dev/install | bash > /dev/null 2>&1 || true
    mkdir -p /paperclip/.codex
    cat > /paperclip/.codex/config.toml << EOF
[mcp_servers.composio-gmail]
url = "url = "https://backend.composio.dev/v3.1/mcp/a6454f21-b7a0-4513-9f8b-c9c9b088e1b7?user_id=default""
http_headers = { "x-api-key" = "$COMPOSIO_API_KEY" }
enabled = true
startup_timeout_sec = 30
tool_timeout_sec = 60
EOF
    export PATH="/root/.composio:$PATH"
fi

if [ "$(id -u)" -ne 0 ]; then
    if [ "$(id -u)" -ne "$PUID" ] || [ "$(id -g)" -ne "$PGID" ]; then
        echo "docker-entrypoint.sh: running unprivileged as $(id -u):$(id -g); cannot remap to requested ${PUID}:${PGID}" >&2
    fi
    exec "$@"
fi
# Adjust the node user's UID/GID if they differ from the runtime request
# and fix volume ownership only when a remap is needed
changed=0
if [ "$(id -u node)" -ne "$PUID" ]; then
    echo "Updating node UID to $PUID"
    usermod -o -u "$PUID" node
    changed=1
fi
if [ "$(id -g node)" -ne "$PGID" ]; then
    echo "Updating node GID to $PGID"
    groupmod -o -g "$PGID" node
    usermod -g "$PGID" node
    changed=1
fi
if [ "$changed" = "1" ]; then
    chown -R node:node /paperclip
fi
exec gosu node "$@"
