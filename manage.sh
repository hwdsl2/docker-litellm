#!/bin/bash
#
# https://github.com/hwdsl2/docker-litellm
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

export PATH="/opt/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

LITELLM_DATA="/etc/litellm"
MASTER_KEY_FILE="${LITELLM_DATA}/.master_key"
PORT_FILE="${LITELLM_DATA}/.port"
CONFIG_FILE="${LITELLM_DATA}/config.yaml"
SERVER_ADDR_FILE="${LITELLM_DATA}/.server_addr"
DB_CONFIGURED_MARKER="${LITELLM_DATA}/.db_configured"

exiterr() { echo "Error: $1" >&2; exit 1; }

show_usage() {
  local exit_code="${2:-1}"
  if [ -n "$1" ]; then
    echo "Error: $1" >&2
  fi
  cat 1>&2 <<'EOF'

LiteLLM Docker - Proxy Management
https://github.com/hwdsl2/docker-litellm

Usage: docker exec <container> litellm_manage [options]

Options:
  --listmodels                         list all configured models
  --addmodel   <provider/model>        add a new model (restarts proxy)
               [--key    <api_key>]    API key for the provider (if required)
               [--base-url <url>]      base URL override (e.g. for Ollama)
               [--alias  <name>]       display name for the model (optional)
  --removemodel <model_id>             remove a model by its ID (restarts proxy)
  --showkey                            show the master API key

  Virtual key management (requires LITELLM_DATABASE_URL):
  --createkey                          create a new virtual key
               [--alias  <name>]       key alias / label (optional)
               [--models <m1,m2,...>]  restrict key to specific models (optional)
               [--budget <usd>]        max spend in USD, e.g. 10.0 (optional)
               [--expires <duration>]  expiry, e.g. 30d, 24h (optional)
  --listkeys                           list all virtual keys
  --deletekey  <key>                   delete a virtual key

  -h, --help                           show this help message and exit

Examples:
  docker exec litellm litellm_manage --listmodels
  docker exec litellm litellm_manage --addmodel openai/gpt-4o --key sk-...
  docker exec litellm litellm_manage --addmodel openai/gpt-4o --key sk-... --alias gpt-4o
  docker exec litellm litellm_manage --addmodel ollama/llama3.2 --base-url http://host.docker.internal:11434
  docker exec litellm litellm_manage --removemodel <model_id>
  docker exec litellm litellm_manage --showkey
  docker exec litellm litellm_manage --createkey --alias dev-key --models gpt-4o,claude-3-6-sonnet --budget 20.0
  docker exec litellm litellm_manage --listkeys
  docker exec litellm litellm_manage --deletekey sk-...

EOF
  exit "$exit_code"
}

check_container() {
  if [ ! -f "/.dockerenv" ] && [ ! -f "/run/.containerenv" ] \
    && [ -z "$KUBERNETES_SERVICE_HOST" ] \
    && ! head -n 1 /proc/1/sched 2>/dev/null | grep -q '^run\.sh '; then
    exiterr "This script must be run inside a container (e.g. Docker, Podman)."
  fi
}

load_config() {
  # Load port
  if [ -z "$LITELLM_PORT" ]; then
    if [ -f "$PORT_FILE" ]; then
      LITELLM_PORT=$(cat "$PORT_FILE")
    else
      LITELLM_PORT=4000
    fi
  fi

  # Load master key
  if [ -z "$LITELLM_MASTER_KEY" ]; then
    if [ -f "$MASTER_KEY_FILE" ]; then
      LITELLM_MASTER_KEY=$(cat "$MASTER_KEY_FILE")
    else
      exiterr "Master key not found at ${MASTER_KEY_FILE}. Has the container fully started?"
    fi
  fi

  # Load server address
  if [ -f "$SERVER_ADDR_FILE" ]; then
    SERVER_ADDR=$(cat "$SERVER_ADDR_FILE")
  else
    SERVER_ADDR="<server ip>"
  fi

  API_BASE="http://127.0.0.1:${LITELLM_PORT}"
}

check_server() {
  if ! curl -sf "${API_BASE}/health/liveliness" >/dev/null 2>&1 \
      && ! curl -sf "${API_BASE}/" >/dev/null 2>&1; then
    exiterr "LiteLLM proxy is not responding on port ${LITELLM_PORT}. Is the container running?"
  fi
}

check_db_configured() {
  if [ ! -f "$DB_CONFIGURED_MARKER" ]; then
    exiterr "Virtual key management requires a database. Set LITELLM_DATABASE_URL to a PostgreSQL URL and restart the container."
  fi
}

api_get() {
  local endpoint="$1"
  curl -sf -X GET "${API_BASE}${endpoint}" \
    -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" 2>&1
}

api_post() {
  local endpoint="$1" body="$2"
  curl -sf -X POST "${API_BASE}${endpoint}" \
    -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
    -H "Content-Type: application/json" \
    -d "$body" 2>&1
}

# Pretty-print JSON response, fall back to raw output
pretty_json() {
  python3 -m json.tool 2>/dev/null || cat
}

parse_args() {
  list_models=0
  add_model=0
  remove_model=0
  show_key=0
  create_key=0
  list_keys=0
  delete_key=0

  model_provider=""
  model_key=""
  model_base_url=""
  alias_arg=""
  model_id=""
  key_models=""
  key_budget=""
  key_expires=""
  key_to_delete=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --listmodels)
        list_models=1
        shift
        ;;
      --addmodel)
        add_model=1
        model_provider="$2"
        shift; shift
        ;;
      --removemodel)
        remove_model=1
        model_id="$2"
        shift; shift
        ;;
      --showkey)
        show_key=1
        shift
        ;;
      --createkey)
        create_key=1
        shift
        ;;
      --listkeys)
        list_keys=1
        shift
        ;;
      --deletekey)
        delete_key=1
        key_to_delete="$2"
        shift; shift
        ;;
      --key)
        model_key="$2"
        shift; shift
        ;;
      --base-url)
        model_base_url="$2"
        shift; shift
        ;;
      --alias)
        alias_arg="$2"
        shift; shift
        ;;
      --models)
        key_models="$2"
        shift; shift
        ;;
      --budget)
        key_budget="$2"
        shift; shift
        ;;
      --expires)
        key_expires="$2"
        shift; shift
        ;;
      -h|--help)
        show_usage "" 0
        ;;
      *)
        show_usage "Unknown parameter: $1"
        ;;
    esac
  done
}

check_args() {
  local action_count
  action_count=$((list_models + add_model + remove_model + show_key + create_key + list_keys + delete_key))

  if [ "$action_count" -eq 0 ]; then
    show_usage
  fi
  if [ "$action_count" -gt 1 ]; then
    show_usage "Specify only one action at a time."
  fi

  if [ "$add_model" = 1 ]; then
    if [ -z "$model_provider" ]; then
      exiterr "Missing model. Usage: --addmodel <provider/model>"
    fi
    [ -n "$alias_arg" ] && model_alias="$alias_arg" || model_alias="$model_provider"
  fi

  if [ "$remove_model" = 1 ] && [ -z "$model_id" ]; then
    exiterr "Missing model ID. Use '--listmodels' to find model IDs."
  fi

  if [ "$delete_key" = 1 ] && [ -z "$key_to_delete" ]; then
    exiterr "Missing key. Usage: --deletekey <key>"
  fi
}

do_list_models() {
  echo
  echo "Configured models:"
  echo
  local resp
  resp=$(api_get "/model/info") || exiterr "Failed to retrieve model list. Is the proxy running?"
  printf '%s\n' "$resp" | pretty_json
  echo
  echo "Use '--removemodel <model_id>' to remove a model (the id field shown above)."
  echo
}

do_add_model() {
  echo
  echo "Adding model '${model_alias}' (provider model: ${model_provider})..."

  [ -f "$CONFIG_FILE" ] || exiterr "Config file not found at ${CONFIG_FILE}. Has the container fully started?"

  _MN="$model_alias" _P="$model_provider" \
  _AK="${model_key:-}" _AB="${model_base_url:-}" \
  python3 - << 'PYEOF' || exiterr "Failed to update ${CONFIG_FILE}."
import yaml, uuid, os, sys
cfg = os.environ.get('CONFIG_FILE', '/etc/litellm/config.yaml')
try:
    with open(cfg) as f:
        config = yaml.safe_load(f) or {}
except OSError as e:
    print(f"Error reading {cfg}: {e}", file=sys.stderr)
    sys.exit(1)
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
print(f"  Model ID: {entry['model_info']['id']}")
PYEOF

  echo
  echo "Model '${model_alias}' added successfully."
  echo "Use '--listmodels' to see all configured models after restart."
  echo
  _restart_proxy
}

do_remove_model() {
  echo
  echo "Removing model ID '${model_id}'..."

  [ -f "$CONFIG_FILE" ] || exiterr "Config file not found at ${CONFIG_FILE}. Has the container fully started?"

  _ID="$model_id" \
  python3 - << 'PYEOF' || exiterr "Failed to update ${CONFIG_FILE}."
import yaml, os, sys
cfg = os.environ.get('CONFIG_FILE', '/etc/litellm/config.yaml')
try:
    with open(cfg) as f:
        config = yaml.safe_load(f) or {}
except OSError as e:
    print(f"Error reading {cfg}: {e}", file=sys.stderr)
    sys.exit(1)
ml = config.get('model_list', [])
mid = os.environ['_ID']
new_ml = [m for m in ml if m.get('model_info', {}).get('id') != mid]
if len(new_ml) == len(ml):
    print(f"Error: Model ID '{mid}' not found in config.", file=sys.stderr)
    sys.exit(1)
config['model_list'] = new_ml
with open(cfg, 'w') as f:
    yaml.safe_dump(config, f, default_flow_style=False, allow_unicode=True)
PYEOF

  echo
  echo "Model '${model_id}' removed."
  echo
  _restart_proxy
}

# Send SIGTERM to the run.sh process (PID 1). run.sh's cleanup trap fires,
# shuts down LiteLLM cleanly, and exits — Docker restarts with the new config.
_restart_proxy() {
  echo "Restarting LiteLLM proxy to apply changes..."
  kill -TERM 1 2>/dev/null
  echo "(Container is restarting. Reconnect in a few seconds.)"
  echo
}

do_show_key() {
  echo
  echo "==========================================================="
  echo " LiteLLM proxy master key"
  echo "==========================================================="
  echo " ${LITELLM_MASTER_KEY}"
  echo "==========================================================="
  echo
  echo "Proxy endpoint:  http://${SERVER_ADDR}:${LITELLM_PORT}"
  echo "API docs:        http://${SERVER_ADDR}:${LITELLM_PORT}/docs"
  echo
}

do_create_key() {
  echo
  echo "Creating virtual key..."

  # Build JSON body via Python to handle quoting safely
  _ALIAS="${alias_arg:-}" _MODELS="${key_models:-}" \
  _BUDGET="${key_budget:-}" _EXPIRES="${key_expires:-}" \
  python3 - << 'PYEOF' > /tmp/litellm_key_body.json || exiterr "Failed to build request body."
import json, os
body = {}
alias  = os.environ.get('_ALIAS',   '').strip()
models = os.environ.get('_MODELS',  '').strip()
budget = os.environ.get('_BUDGET',  '').strip()
expires = os.environ.get('_EXPIRES','').strip()
if alias:
    body['key_alias'] = alias
if models:
    body['models'] = [m.strip() for m in models.split(',') if m.strip()]
if budget:
    try:
        body['max_budget'] = float(budget)
    except ValueError:
        import sys
        print(f"Error: --budget must be a number (e.g. 10.0)", file=sys.stderr)
        sys.exit(1)
if expires:
    body['duration'] = expires
print(json.dumps(body))
PYEOF

  local resp
  resp=$(api_post "/key/generate" "$(cat /tmp/litellm_key_body.json)") \
    || exiterr "Failed to create virtual key. Is the proxy running and is a database configured?"
  rm -f /tmp/litellm_key_body.json

  echo
  echo "Virtual key created:"
  echo
  printf '%s\n' "$resp" | pretty_json
  echo
  echo "Store this key securely. The full key value cannot be retrieved again."
  echo
}

do_list_keys() {
  echo
  echo "Virtual keys:"
  echo
  local resp
  resp=$(api_get "/key/list") \
    || exiterr "Failed to list virtual keys. Is the proxy running and is a database configured?"
  printf '%s\n' "$resp" | pretty_json
  echo
}

do_delete_key() {
  echo
  echo "Deleting virtual key '${key_to_delete}'..."

  local body
  body=$(_KEY="$key_to_delete" python3 -c \
    "import json,os; print(json.dumps({'keys': [os.environ['_KEY']]}))")

  api_post "/key/delete" "$body" >/dev/null \
    || exiterr "Failed to delete virtual key. Is the proxy running and is a database configured?"

  echo
  echo "Virtual key deleted."
  echo
}

check_container
load_config
parse_args "$@"
check_args

# Operations that do not require the proxy to be running
if [ "$show_key" = 1 ]; then
  do_show_key
  exit 0
fi

if [ "$add_model" = 1 ]; then
  do_add_model
  exit 0
fi

if [ "$remove_model" = 1 ]; then
  do_remove_model
  exit 0
fi

# Virtual key operations: require DB marker + running proxy
if [ "$create_key" = 1 ]; then
  check_db_configured
  check_server
  do_create_key
  exit 0
fi

if [ "$list_keys" = 1 ]; then
  check_db_configured
  check_server
  do_list_keys
  exit 0
fi

if [ "$delete_key" = 1 ]; then
  check_db_configured
  check_server
  do_delete_key
  exit 0
fi

# Remaining operations require the proxy to be running
check_server

if [ "$list_models" = 1 ]; then
  do_list_models
  exit 0
fi