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
LITELLM_DATABASE_URL=$(nospaces "$LITELLM_DATABASE_URL")
LITELLM_DATABASE_URL=$(noquotes "$LITELLM_DATABASE_URL")
LITELLM_HOST=$(nospaces "$LITELLM_HOST")
LITELLM_HOST=$(noquotes "$LITELLM_HOST")

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
mkdir -p /etc/litellm

MASTER_KEY_FILE="/etc/litellm/.master_key"
PORT_FILE="/etc/litellm/.port"
SERVER_ADDR_FILE="/etc/litellm/.server_addr"
INITIALIZED_MARKER="/etc/litellm/.initialized"
DB_CONFIGURED_MARKER="/etc/litellm/.db_configured"

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
    server_addr="<server ip>"
  fi
fi
printf '%s' "$server_addr" > "$SERVER_ADDR_FILE"

echo
echo "LiteLLM Docker - https://github.com/hwdsl2/docker-litellm"

# Configure database if specified
if [ -n "$LITELLM_DATABASE_URL" ]; then
  export DATABASE_URL="$LITELLM_DATABASE_URL"
  touch "$DB_CONFIGURED_MARKER"
  echo
  echo "Applying database schema..."
  LITELLM_SCHEMA=$(/opt/venv/bin/python3 -c \
    'import litellm, os; print(os.path.join(os.path.dirname(litellm.__file__), "proxy", "schema.prisma"))')
  if ! prisma db push --schema "$LITELLM_SCHEMA" --skip-generate 2>&1; then
    echo "Warning: Failed to apply database schema. Virtual key management may not work." >&2
  fi
else
  rm -f "$DB_CONFIGURED_MARKER"
fi

if ! grep -q " /etc/litellm " /proc/mounts 2>/dev/null; then
  echo
  echo "Note: /etc/litellm is not mounted. Proxy data (master key, model"
  echo "      configurations) will be lost on container removal."
  echo "      Mount a Docker volume at /etc/litellm to persist data."
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
    echo "  Adding Ollama model (ollama/llama3.2)..."
    add_model_to_config "ollama/llama3.2" "ollama/llama3.2" "" "$LITELLM_OLLAMA_BASE_URL"
    added_models=$((added_models + 1))
  fi

  touch "$INITIALIZED_MARKER"
else
  echo
  echo "Found existing LiteLLM data, starting proxy..."
  echo
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

# Wait for LiteLLM to become ready (up to 60 seconds)
wait_for_server() {
  local i=0
  while [ "$i" -lt 60 ]; do
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
    echo "Error: LiteLLM did not become ready after 60 seconds." >&2
    kill "$LITELLM_PID" 2>/dev/null
  fi
  exit 1
fi

# First-run: display summary once the proxy is confirmed ready
if $first_run; then
  echo
  echo "==========================================================="
  echo " LiteLLM proxy master key"
  echo "==========================================================="
  echo " ${master_key}"
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