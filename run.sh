#!/bin/bash
#
# Docker script to configure and start a LiteLLM AI gateway proxy
#
# DO NOT RUN THIS SCRIPT ON YOUR PC OR MAC! THIS IS ONLY MEANT TO BE RUN
# IN A CONTAINER!
#
# This file is part of LiteLLM Docker image, available at:
# https://github.com/hwdsl2/docker-litellm
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

export PATH="/opt/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

exiterr()  { echo "Error: $1" >&2; exit 1; }
nospaces() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
noquotes() { printf '%s' "$1" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"; }

urlencode_component() {
  python3 - "$1" <<'PYEOF'
import sys
from urllib.parse import quote

print(quote(sys.argv[1], safe=""))
PYEOF
}

check_port() {
  printf '%s' "$1" | tr -d '\n' | grep -Eq '^[0-9]+$' \
  && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

check_ip() {
  IP_REGEX='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$IP_REGEX"
}

check_dns_name() {
  FQDN_REGEX='^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$FQDN_REGEX"
}

# Source bind-mounted env file if present (takes precedence over --env-file)
if [ -f /litellm.env ]; then
  # shellcheck disable=SC1091
  . /litellm.env
fi

if [ ! -f "/.dockerenv" ] && [ ! -f "/run/.containerenv" ] \
  && [ -z "$KUBERNETES_SERVICE_HOST" ] \
  && ! head -n 1 /proc/1/sched 2>/dev/null | grep -q '^run\.sh '; then
  exiterr "This script ONLY runs in a container (e.g. Docker, Podman)."
fi

# Read and sanitize environment variables
LITELLM_PORT=$(nospaces "$LITELLM_PORT")
LITELLM_PORT=$(noquotes "$LITELLM_PORT")
LITELLM_MASTER_KEY=$(nospaces "$LITELLM_MASTER_KEY")
LITELLM_MASTER_KEY=$(noquotes "$LITELLM_MASTER_KEY")
LITELLM_LOG_LEVEL=$(nospaces "$LITELLM_LOG_LEVEL")
LITELLM_LOG_LEVEL=$(noquotes "$LITELLM_LOG_LEVEL")
LITELLM_OPENAI_API_KEY=$(nospaces "$LITELLM_OPENAI_API_KEY")
LITELLM_OPENAI_API_KEY=$(noquotes "$LITELLM_OPENAI_API_KEY")
LITELLM_ANTHROPIC_API_KEY=$(nospaces "$LITELLM_ANTHROPIC_API_KEY")
LITELLM_ANTHROPIC_API_KEY=$(noquotes "$LITELLM_ANTHROPIC_API_KEY")
LITELLM_GROQ_API_KEY=$(nospaces "$LITELLM_GROQ_API_KEY")
LITELLM_GROQ_API_KEY=$(noquotes "$LITELLM_GROQ_API_KEY")
LITELLM_GEMINI_API_KEY=$(nospaces "$LITELLM_GEMINI_API_KEY")
LITELLM_GEMINI_API_KEY=$(noquotes "$LITELLM_GEMINI_API_KEY")
LITELLM_OLLAMA_BASE_URL=$(nospaces "$LITELLM_OLLAMA_BASE_URL")
LITELLM_OLLAMA_BASE_URL=$(noquotes "$LITELLM_OLLAMA_BASE_URL")
LITELLM_OLLAMA_API_KEY=$(nospaces "$LITELLM_OLLAMA_API_KEY")
LITELLM_OLLAMA_API_KEY=$(noquotes "$LITELLM_OLLAMA_API_KEY")
LITELLM_DATABASE_URL=$(nospaces "$LITELLM_DATABASE_URL")
LITELLM_DATABASE_URL=$(noquotes "$LITELLM_DATABASE_URL")
LITELLM_POSTGRES_PASSWORD_FILE=$(nospaces "$LITELLM_POSTGRES_PASSWORD_FILE")
LITELLM_POSTGRES_PASSWORD_FILE=$(noquotes "$LITELLM_POSTGRES_PASSWORD_FILE")
LITELLM_HOST=$(nospaces "$LITELLM_HOST")
LITELLM_HOST=$(noquotes "$LITELLM_HOST")
LITELLM_MCP_URL=$(nospaces "$LITELLM_MCP_URL")
LITELLM_MCP_URL=$(noquotes "$LITELLM_MCP_URL")
LITELLM_MCP_API_KEY=$(nospaces "$LITELLM_MCP_API_KEY")
LITELLM_MCP_API_KEY=$(noquotes "$LITELLM_MCP_API_KEY")

# Apply defaults
[ -z "$LITELLM_PORT" ]      && LITELLM_PORT=4000
[ -z "$LITELLM_LOG_LEVEL" ] && LITELLM_LOG_LEVEL=INFO

# Validate port
if ! check_port "$LITELLM_PORT"; then
  exiterr "LITELLM_PORT must be an integer between 1 and 65535."
fi

# Validate log level
case "$LITELLM_LOG_LEVEL" in
  DEBUG|INFO|WARNING|ERROR|CRITICAL) ;;
  *) exiterr "LITELLM_LOG_LEVEL must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL." ;;
esac

# Build the default Compose database URL from a password file when no explicit URL
# is provided. This keeps LITELLM_DATABASE_URL as the most flexible override.
if [ -z "$LITELLM_DATABASE_URL" ] && [ -n "$LITELLM_POSTGRES_PASSWORD_FILE" ]; then
  if [ ! -r "$LITELLM_POSTGRES_PASSWORD_FILE" ]; then
    exiterr "LITELLM_POSTGRES_PASSWORD_FILE '$LITELLM_POSTGRES_PASSWORD_FILE' is not readable."
  fi
  LITELLM_POSTGRES_PASSWORD=$(cat "$LITELLM_POSTGRES_PASSWORD_FILE")
  LITELLM_POSTGRES_PASSWORD=$(nospaces "$LITELLM_POSTGRES_PASSWORD")
  LITELLM_POSTGRES_PASSWORD=$(noquotes "$LITELLM_POSTGRES_PASSWORD")
  if [ -z "$LITELLM_POSTGRES_PASSWORD" ]; then
    exiterr "LITELLM_POSTGRES_PASSWORD_FILE '$LITELLM_POSTGRES_PASSWORD_FILE' is empty."
  fi
  ENCODED_POSTGRES_PASSWORD=$(urlencode_component "$LITELLM_POSTGRES_PASSWORD") \
    || exiterr "Failed to URL-encode Postgres password."
  LITELLM_DATABASE_URL="postgresql://litellm:${ENCODED_POSTGRES_PASSWORD}@db:5432/litellm"
fi

# Validate database URL
if [ -n "$LITELLM_DATABASE_URL" ]; then
  case "$LITELLM_DATABASE_URL" in
    postgresql://*|postgres://*) ;;
    *) exiterr "LITELLM_DATABASE_URL must be a PostgreSQL connection URL (postgresql://... or postgres://...)." ;;
  esac
fi

# Validate server hostname/IP
if [ -n "$LITELLM_HOST" ]; then
  if ! check_dns_name "$LITELLM_HOST" && ! check_ip "$LITELLM_HOST"; then
    exiterr "LITELLM_HOST '$LITELLM_HOST' is not a valid hostname or IP address."
  fi
fi

# Ensure data directory exists
DATA_DIR="/etc/litellm"
mkdir -p "$DATA_DIR"

MASTER_KEY_FILE="${DATA_DIR}/.master_key"
PORT_FILE="${DATA_DIR}/.port"
INITIALIZED_MARKER="${DATA_DIR}/.initialized"
DB_CONFIGURED_MARKER="${DATA_DIR}/.db_configured"
USAGE_STATE_DIR="${DATA_DIR}/.litellm-usage"
USAGE_BASE_URL=${LITELLM_USAGE_BASE_URL:-https://github.com/hwdsl2/ai-stack-extras/releases/download/v1.0.0}
data_mounted=false
data_existing=false

if grep -q " ${DATA_DIR} " /proc/mounts 2>/dev/null; then
  data_mounted=true
fi
if $data_mounted && find "$DATA_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .; then
  data_existing=true
fi

usage_arch() {
  local arch
  arch=$(uname -m 2>/dev/null || printf 'unknown')
  case "$arch" in
    x86_64|amd64) printf 'amd64' ;;
    aarch64|arm64) printf 'arm64' ;;
    *) printf 'other' ;;
  esac
}

write_usage_state() {
  local state_file version tmp_file
  state_file=$1
  version=$2
  mkdir -p "$USAGE_STATE_DIR"
  tmp_file=$(mktemp "$USAGE_STATE_DIR/.usage.XXXXXX")
  printf '%s\n' "$version" > "$tmp_file"
  chmod 0644 "$tmp_file" 2>/dev/null || true
  mv "$tmp_file" "$state_file"
}

fetch_usage_asset() {
  local asset base_url
  asset=$1
  base_url=${USAGE_BASE_URL%/}
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time 5 -o /dev/null "$base_url/$asset" >/dev/null 2>&1
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T 5 -O /dev/null "$base_url/$asset" >/dev/null 2>&1
  else
    return 1
  fi
}

read_state_value() {
  [ -r "$1" ] || return 0
  tr -d '[:space:]' < "$1"
}

report_usage_counts() {
  local current_version arch state_file last_version action

  [ "${LITELLM_DISABLE_USAGE_COUNTS:-0}" != "1" ] || return 0
  $data_mounted || return 0

  current_version="${IMAGE_FLAVOR:-unknown}-${IMAGE_VER:-unknown}"
  arch=$(usage_arch)

  state_file="$USAGE_STATE_DIR/litellm.version"
  last_version=$(read_state_value "$state_file")
  action=

  if [ -z "$last_version" ]; then
    if $data_existing; then
      action=upgrade
    else
      action=deploy
    fi
  elif [ "$last_version" != "$current_version" ]; then
    action=upgrade
  fi

  if [ -n "$action" ]; then
    if fetch_usage_asset "cu-v1-litellm-$action-cpu-$arch"; then
      write_usage_state "$state_file" "$current_version"
    fi
  fi
}

# Generate or load master key
if [ -n "$LITELLM_MASTER_KEY" ]; then
  master_key="$LITELLM_MASTER_KEY"
  # Sync to file so litellm_manage can read it without needing the env var
  printf '%s' "$master_key" > "$MASTER_KEY_FILE"
  chmod 600 "$MASTER_KEY_FILE"
else
  if [ -f "$MASTER_KEY_FILE" ]; then
    master_key=$(cat "$MASTER_KEY_FILE")
  else
    master_key="sk-$(head -c 48 /dev/urandom | od -A n -t x1 | tr -d ' \n' | head -c 64)"
    printf '%s' "$master_key" > "$MASTER_KEY_FILE"
    chmod 600 "$MASTER_KEY_FILE"
  fi
fi

# Export master key so LiteLLM reads it directly from the environment
export LITELLM_MASTER_KEY="$master_key"

# Save port for use by litellm_manage
printf '%s' "$LITELLM_PORT" > "$PORT_FILE"

# Determine server address for display
if [ -n "$LITELLM_HOST" ]; then
  server_addr="$LITELLM_HOST"
else
  public_ip=$(wget -t 2 -T 10 -qO- http://ipv4.icanhazip.com 2>/dev/null)
  check_ip "$public_ip" || public_ip=$(wget -t 2 -T 10 -qO- http://ip1.dynupdate.no-ip.com 2>/dev/null)
  if check_ip "$public_ip"; then
    server_addr="$public_ip"
  else
    server_addr="<server-ip>"
  fi
fi
echo
echo "LiteLLM Docker - https://github.com/hwdsl2/docker-litellm"

# Configure database if specified
if [ -n "$LITELLM_DATABASE_URL" ]; then
  export DATABASE_URL="$LITELLM_DATABASE_URL"
  touch "$DB_CONFIGURED_MARKER"
else
  rm -f "$DB_CONFIGURED_MARKER"
fi

if ! grep -q " /etc/litellm " /proc/mounts 2>/dev/null; then
  echo
  echo "Note: /etc/litellm is not mounted. Proxy data (master key, model"
  echo "      configurations) will be lost on container removal."
  echo "      Mount a Docker volume at /etc/litellm to persist data."
fi

# Auto-read API keys from shared volumes if mounted (used by self-hosted-ai-stack)
if [ -z "$LITELLM_OLLAMA_API_KEY" ] && grep -q " /var/lib/ollama-shared " /proc/mounts 2>/dev/null; then
  if [ -f /var/lib/ollama-shared/.api_key ]; then
    LITELLM_OLLAMA_API_KEY=$(cat /var/lib/ollama-shared/.api_key)
  fi
fi
if [ -z "$LITELLM_MCP_API_KEY" ] && grep -q " /var/lib/mcp-shared " /proc/mounts 2>/dev/null; then
  if [ -f /var/lib/mcp-shared/.api_key ]; then
    LITELLM_MCP_API_KEY=$(cat /var/lib/mcp-shared/.api_key)
  fi
fi

# Export provider API keys as standard environment variables for LiteLLM
[ -n "$LITELLM_OPENAI_API_KEY" ]    && export OPENAI_API_KEY="$LITELLM_OPENAI_API_KEY"
[ -n "$LITELLM_ANTHROPIC_API_KEY" ] && export ANTHROPIC_API_KEY="$LITELLM_ANTHROPIC_API_KEY"
[ -n "$LITELLM_GROQ_API_KEY" ]      && export GROQ_API_KEY="$LITELLM_GROQ_API_KEY"
[ -n "$LITELLM_GEMINI_API_KEY" ]    && export GEMINI_API_KEY="$LITELLM_GEMINI_API_KEY"

# Set log level via environment variable
export LITELLM_LOG="$LITELLM_LOG_LEVEL"

# Helper: append one model entry to /etc/litellm/config.yaml.
# Passes data via environment variables to avoid shell-quoting issues in Python.
add_model_to_config() {
  local model_name="$1" provider="$2" api_key="$3" api_base="$4"
  _MN="$model_name" _P="$provider" _AK="${api_key:-}" _AB="${api_base:-}" \
  python3 - << 'PYEOF'
import yaml, uuid, os
cfg = '/etc/litellm/config.yaml'
with open(cfg) as f:
    config = yaml.safe_load(f) or {}
entry = {
    'model_name': os.environ['_MN'],
    'litellm_params': {'model': os.environ['_P']},
    'model_info': {'id': str(uuid.uuid4())},
}
if os.environ.get('_AK'):
    entry['litellm_params']['api_key'] = os.environ['_AK']
if os.environ.get('_AB'):
    entry['litellm_params']['api_base'] = os.environ['_AB']
config.setdefault('model_list', []).append(entry)
with open(cfg, 'w') as f:
    yaml.safe_dump(config, f, default_flow_style=False, allow_unicode=True)
PYEOF
}

ensure_model_in_config() {
  local model_name="$1" provider="$2" api_key="$3" api_base="$4" supports_function_calling="${5:-false}" update_existing="${6:-true}"
  _MN="$model_name" _P="$provider" _AK="${api_key:-}" _AB="${api_base:-}" _SFC="$supports_function_calling" _UPDATE="$update_existing" \
  python3 - << 'PYEOF'
import os
import uuid
import yaml

cfg = '/etc/litellm/config.yaml'
with open(cfg) as f:
    config = yaml.safe_load(f) or {}

model_name = os.environ['_MN']
models = config.setdefault('model_list', [])
matches = [m for m in models if m.get('model_name') == model_name]
if matches and os.environ.get('_UPDATE') != 'true':
    raise SystemExit(0)

entry = dict(matches[0]) if matches else {}

entry['model_name'] = model_name
entry['litellm_params'] = dict(entry.get('litellm_params') or {})
entry['litellm_params']['model'] = os.environ['_P']
if os.environ.get('_AB'):
    entry['litellm_params']['api_base'] = os.environ['_AB']
else:
    entry['litellm_params'].pop('api_base', None)
if os.environ.get('_AK'):
    entry['litellm_params']['api_key'] = os.environ['_AK']
else:
    entry['litellm_params'].pop('api_key', None)

entry['model_info'] = dict(entry.get('model_info') or {})
entry['model_info'].setdefault('id', str(uuid.uuid4()))
if os.environ.get('_SFC') == 'true':
    entry['model_info']['supports_function_calling'] = True

new_models = []
inserted = False
for model in models:
    if model.get('model_name') == model_name:
        if not inserted:
            new_models.append(entry)
            inserted = True
        continue
    new_models.append(model)
if not inserted:
    new_models.append(entry)

config['model_list'] = new_models
with open(cfg, 'w') as f:
    yaml.safe_dump(config, f, default_flow_style=False, allow_unicode=True)
PYEOF
}

# Create config.yaml only if it does not yet exist.
# On subsequent restarts the existing file is preserved, keeping model_list intact.
if [ ! -f /etc/litellm/config.yaml ]; then
  cat > /etc/litellm/config.yaml << 'EOF'
# LiteLLM Proxy Configuration
# Managed by docker-litellm — do not edit manually.
# Use 'litellm_manage' to add or remove models.
# https://github.com/hwdsl2/docker-litellm

model_list: []

litellm_settings:
  drop_params: true
  set_verbose: false
EOF
  chmod 600 /etc/litellm/config.yaml
fi

# Inject or remove mcp_servers: block based on LITELLM_MCP_URL.
# This runs on every start so the config always reflects the current env file.
if [ -n "$LITELLM_MCP_URL" ]; then
  _MCP_URL="$LITELLM_MCP_URL" _MCP_KEY="${LITELLM_MCP_API_KEY:-}" \
  python3 - << 'PYEOF'
import yaml, os
cfg = '/etc/litellm/config.yaml'
with open(cfg) as f:
    config = yaml.safe_load(f) or {}
entry = {'url': os.environ['_MCP_URL'], 'transport': 'http'}
key = os.environ.get('_MCP_KEY', '')
if key:
    entry['auth_type'] = 'bearer_token'
    entry['auth_value'] = key
config['mcp_servers'] = {'docker_mcp_gateway': entry}
with open(cfg, 'w') as f:
    yaml.safe_dump(config, f, default_flow_style=False, allow_unicode=True)
PYEOF
else
  # Remove mcp_servers block if LITELLM_MCP_URL is unset
  python3 - << 'PYEOF'
import yaml
cfg = '/etc/litellm/config.yaml'
with open(cfg) as f:
    config = yaml.safe_load(f) or {}
config.pop('mcp_servers', None)
with open(cfg, 'w') as f:
    yaml.safe_dump(config, f, default_flow_style=False, allow_unicode=True)
PYEOF
fi

# Detect first run before any initialization
first_run=false
[ ! -f "$INITIALIZED_MARKER" ] && first_run=true

added_models=0

if $first_run; then
  echo
  echo "Starting LiteLLM first-run setup..."
  echo "Port:      $LITELLM_PORT"
  echo "Log level: $LITELLM_LOG_LEVEL"
  echo

  # Add models for each configured provider API key directly into config.yaml
  if [ -n "$LITELLM_OPENAI_API_KEY" ]; then
    echo "  Adding OpenAI models (gpt-4o, gpt-4o-mini)..."
    add_model_to_config "gpt-4o"      "openai/gpt-4o"      "$LITELLM_OPENAI_API_KEY" ""
    add_model_to_config "gpt-4o-mini" "openai/gpt-4o-mini" "$LITELLM_OPENAI_API_KEY" ""
    added_models=$((added_models + 2))
  fi

  if [ -n "$LITELLM_ANTHROPIC_API_KEY" ]; then
    echo "  Adding Anthropic model (claude-3-6-sonnet-latest)..."
    add_model_to_config "claude-3-6-sonnet" "anthropic/claude-3-6-sonnet-latest" \
      "$LITELLM_ANTHROPIC_API_KEY" ""
    added_models=$((added_models + 1))
  fi

  if [ -n "$LITELLM_GROQ_API_KEY" ]; then
    echo "  Adding Groq model (llama-3.3-70b-versatile)..."
    add_model_to_config "llama-3.3-70b" "groq/llama-3.3-70b-versatile" \
      "$LITELLM_GROQ_API_KEY" ""
    added_models=$((added_models + 1))
  fi

  if [ -n "$LITELLM_GEMINI_API_KEY" ]; then
    echo "  Adding Gemini model (gemini-2.0-flash)..."
    add_model_to_config "gemini-2.0-flash" "gemini/gemini-2.0-flash" \
      "$LITELLM_GEMINI_API_KEY" ""
    added_models=$((added_models + 1))
  fi

  if [ -n "$LITELLM_OLLAMA_BASE_URL" ]; then
    echo "  Adding Ollama models (ollama/llama3.2:3b, ollama-chat/llama3.2:3b)..."
    added_models=$((added_models + 2))
  fi

  touch "$INITIALIZED_MARKER"
else
  echo
  echo "Found existing LiteLLM data, starting proxy..."
  echo
fi

if [ -n "$LITELLM_OLLAMA_BASE_URL" ]; then
  echo "Ensuring Ollama model alias (ollama/llama3.2:3b)..."
  ensure_model_in_config "ollama/llama3.2:3b" "ollama/llama3.2:3b" \
    "$LITELLM_OLLAMA_API_KEY" "$LITELLM_OLLAMA_BASE_URL" "false" "false" \
    || exiterr "Failed to update Ollama model alias."
  echo "Ensuring Ollama chat model alias (ollama-chat/llama3.2:3b)..."
  ensure_model_in_config "ollama-chat/llama3.2:3b" "ollama_chat/llama3.2:3b" \
    "$LITELLM_OLLAMA_API_KEY" "$LITELLM_OLLAMA_BASE_URL" "true" "true" \
    || exiterr "Failed to update Ollama chat model alias."
fi

# Graceful shutdown handler — registered before starting LiteLLM so any
# SIGTERM received during startup is handled cleanly.
cleanup() {
  echo
  echo "Stopping LiteLLM..."
  kill "${LITELLM_PID:-}" 2>/dev/null
  wait "${LITELLM_PID:-}" 2>/dev/null
  exit 0
}
trap cleanup INT TERM

echo "Starting LiteLLM proxy on port ${LITELLM_PORT}... (this may take about a minute)"
echo

# Start LiteLLM proxy in the background
litellm --config /etc/litellm/config.yaml \
  --port "$LITELLM_PORT" \
  --host 0.0.0.0 &
LITELLM_PID=$!

# Wait for LiteLLM to become ready
wait_for_server() {
  local i=0
  while [ "$i" -lt 600 ]; do
    if ! kill -0 "$LITELLM_PID" 2>/dev/null; then
      return 1
    fi
    if curl -sf "http://127.0.0.1:${LITELLM_PORT}/health/liveliness" >/dev/null 2>&1 \
        || curl -sf "http://127.0.0.1:${LITELLM_PORT}/" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    i=$((i + 1))
  done
  return 1
}

if ! wait_for_server; then
  if ! kill -0 "$LITELLM_PID" 2>/dev/null; then
    echo "Error: LiteLLM failed to start. Check the container logs for details." >&2
  else
    echo "Error: LiteLLM did not become ready after 600 seconds." >&2
    kill "$LITELLM_PID" 2>/dev/null
  fi
  exit 1
fi

report_usage_counts

# Copy master key to shared volume if mounted (used by self-hosted-ai-stack)
if grep -q " /var/lib/litellm-shared " /proc/mounts 2>/dev/null; then
  cp "$MASTER_KEY_FILE" /var/lib/litellm-shared/.api_key
  chmod 644 /var/lib/litellm-shared/.api_key
fi

# First-run: display summary once the proxy is confirmed ready
if $first_run; then
  echo
  echo "==========================================================="
  echo "LiteLLM proxy master key"
  echo "==========================================================="
  echo "${master_key}"
  echo "==========================================================="
  echo
  echo "Proxy endpoint: http://${server_addr}:${LITELLM_PORT}"
  echo "Proxy UI:       http://${server_addr}:${LITELLM_PORT}/ui"
  echo
  echo "To set up HTTPS, see: Using a reverse proxy"
  echo "  https://github.com/hwdsl2/docker-litellm#using-a-reverse-proxy"
  echo
  echo "Test with OpenAI-compatible API:"
  echo "  curl http://${server_addr}:${LITELLM_PORT}/v1/models \\"
  echo "    -H \"Authorization: Bearer ${master_key}\""
  echo
  if [ "$added_models" -gt 0 ]; then
    echo "Models configured: $added_models"
    echo "List models: docker exec <container> litellm_manage --listmodels"
    echo
  else
    echo "No provider API keys set. Add models with:"
    echo "  docker exec <container> litellm_manage --addmodel openai/gpt-4o --key sk-..."
    echo
  fi
  if [ -n "$LITELLM_DATABASE_URL" ]; then
    echo "Virtual key management: enabled (database configured)"
    echo "Create keys: docker exec <container> litellm_manage --createkey"
    echo
  fi
  echo "Setup complete."
  echo
fi

# Wait for LiteLLM to exit
wait "$LITELLM_PID"
