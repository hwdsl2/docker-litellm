[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# LiteLLM AI Gateway on Docker

[![Build Status](https://github.com/hwdsl2/docker-litellm/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-litellm/actions/workflows/main.yml) &nbsp;[![Docker Pulls](https://raw.githubusercontent.com/hwdsl2/badges/main/img/docker-pulls-litellm-server.svg)](https://hub.docker.com/r/hwdsl2/litellm-server) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

Part of the [Self-Hosted AI Stack](https://github.com/hwdsl2/self-hosted-ai-stack) — deploy a complete self-hosted AI stack with a single command.

Docker image to run a [LiteLLM](https://github.com/BerriAI/litellm) AI gateway proxy. Provides a single OpenAI-compatible API endpoint in front of 100+ LLM providers. Based on Debian (python:3.12-slim). Designed to be simple, private, and self-hosted.

**Features:**

- **Secure by default** — automatically generates a master API key on first start; all API requests require this key
- Auto-adds models for any provider API keys set in the env file
- Model management via a helper script (`litellm_manage`)
- The `docker-compose.yml` includes a PostgreSQL database for the Admin UI, virtual key management, and spend tracking
- OpenAI-compatible proxy API — point OpenAI SDK and app workflows at your proxy with a one-line change
- Supports OpenAI, Anthropic, Groq, Gemini, Ollama, and [100+ other providers](https://docs.litellm.ai/docs/providers)
- Supported endpoints and fields depend on LiteLLM, the selected provider, and model capabilities
- Automatically built and published via [GitHub Actions](https://github.com/hwdsl2/docker-litellm/actions/workflows/main.yml)
- Persistent data via a Docker volume
- Multi-arch: `linux/amd64`, `linux/arm64`

**Also available:**

- AI stack: [Self-Hosted AI Stack](https://github.com/hwdsl2/self-hosted-ai-stack)
- Related AI services: [Whisper (STT)](https://github.com/hwdsl2/docker-whisper), [Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro), [Embeddings](https://github.com/hwdsl2/docker-embeddings), [Ollama (LLM)](https://github.com/hwdsl2/docker-ollama), [Docling](https://github.com/hwdsl2/docker-docling), [MCP Gateway](https://github.com/hwdsl2/docker-mcp-gateway)

## Community

- 📬 [Subscribe for project updates](https://selfhostedstack.beehiiv.com/subscribe?utm_campaign=ai) (1–2 emails/month) — get free AI and VPN deployment guides (PDF)
- 💬 Join the [r/selfhostedstack](https://www.reddit.com/r/selfhostedstack/) community for discussions and showcases
- ⭐ Star the repository if you find it useful — it helps others discover it

Other self-hosted projects: [Setup IPsec VPN](https://github.com/hwdsl2/setup-ipsec-vpn), [IPsec VPN on Docker](https://github.com/hwdsl2/docker-ipsec-vpn-server), [WireGuard](https://github.com/hwdsl2/docker-wireguard), [OpenVPN](https://github.com/hwdsl2/docker-openvpn), [Headscale](https://github.com/hwdsl2/docker-headscale).

## Quick start

**Step 1.** Start the LiteLLM proxy:

```bash
docker run \
    --name litellm \
    --restart=always \
    -v litellm-data:/etc/litellm \
    -p 4000:4000/tcp \
    -d hwdsl2/litellm-server
```

On first start, the server automatically generates a master API key and creates a config. The master key is printed to the container logs.

**Note:** For internet-facing deployments, using a [reverse proxy](#using-a-reverse-proxy) to add HTTPS is **strongly recommended**. In that case, also replace `-p 4000:4000/tcp` with `-p 127.0.0.1:4000:4000/tcp` in the `docker run` command above, to prevent direct access to the unencrypted port.

**Step 2.** View the container logs to get the master key:

```bash
docker logs litellm
```

The master key is displayed in a box labeled **LiteLLM proxy master key**. Copy this key — you will use it to authenticate all API requests.

**Note:** The master key is only printed during the first-run setup. To display it again at any time, run:

```bash
docker exec litellm litellm_manage --showkey
```

**Step 3.** Test the proxy with an OpenAI-compatible request:

```bash
# List available models
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer <your-master-key>"

# Send a chat completion (after adding a model — see below)
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer <your-master-key>" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o", "messages": [{"role": "user", "content": "Hello!"}]}'
```

**Note:** The chat completion command above requires a model to be configured first. See [Model management](#model-management).

To learn more about how to use this image, read the sections below.

## Requirements

- A Linux server (local or cloud) with Docker installed
- At least one LLM provider API key (OpenAI, Anthropic, Groq, etc.) **or** a locally running [Ollama](https://github.com/hwdsl2/docker-ollama) instance
- TCP port 4000 (or your configured port) open and accessible

No LLM provider keys are required to start the proxy — the server starts successfully with an empty model list. Add models at any time using `litellm_manage`.

For internet-facing deployments, see [Using a reverse proxy](#using-a-reverse-proxy) to add HTTPS.

## Download

Get the trusted build from the [Docker Hub registry](https://hub.docker.com/r/hwdsl2/litellm-server/):

```bash
docker pull hwdsl2/litellm-server
```

Alternatively, you may download from [Quay.io](https://quay.io/repository/hwdsl2/litellm-server):

```bash
docker pull quay.io/hwdsl2/litellm-server
docker image tag quay.io/hwdsl2/litellm-server hwdsl2/litellm-server
```

Supported platforms: `linux/amd64` and `linux/arm64`.

## Environment variables

All variables are optional. The master API key is auto-generated on first start if `LITELLM_MASTER_KEY` is not set.

This Docker image uses the following variables, that can be declared in an `env` file (see [example](litellm.env.example)):

| Variable | Description | Default |
|---|---|---|
| `LITELLM_MASTER_KEY` | Master API key for the proxy | Auto-generated |
| `LITELLM_PORT` | TCP port for the proxy (1–65535) | `4000` |
| `LITELLM_HOST` | Hostname or IP shown in startup info and `--showkey` output | Auto-detected |
| `LITELLM_LOG_LEVEL` | Log level: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` | `INFO` |
| `LITELLM_OPENAI_API_KEY` | OpenAI API key — auto-adds `gpt-4o`, `gpt-4o-mini` | *(not set)* |
| `LITELLM_ANTHROPIC_API_KEY` | Anthropic API key — auto-adds `claude-3-6-sonnet` (latest) | *(not set)* |
| `LITELLM_GROQ_API_KEY` | Groq API key — auto-adds `llama-3.3-70b` | *(not set)* |
| `LITELLM_GEMINI_API_KEY` | Google Gemini API key — auto-adds `gemini-2.0-flash` | *(not set)* |
| `LITELLM_OLLAMA_BASE_URL` | Ollama base URL — ensures `ollama/llama3.2:3b` and `ollama-chat/llama3.2:3b` | *(not set)* |
| `LITELLM_OLLAMA_API_KEY` | Ollama API key (auto-read from shared volume in [self-hosted-ai-stack](https://github.com/hwdsl2/self-hosted-ai-stack)) | *(not set)* |
| `LITELLM_DATABASE_URL` | PostgreSQL URL — enables virtual key management | *(not set)* |
| `LITELLM_POSTGRES_PASSWORD_FILE` | File containing the Compose Postgres password; used only when `LITELLM_DATABASE_URL` is not set | *(not set)* |
| `LITELLM_MCP_URL` | MCP Gateway endpoint URL — auto-wires MCP Gateway on every start | *(not set)* |
| `LITELLM_MCP_API_KEY` | Bearer token for the MCP Gateway (required when `LITELLM_MCP_URL` is set) | *(not set)* |

**Note:** In your `env` file, you may enclose values in single quotes, e.g. `VAR='value'`. Do not add spaces around `=`. If you change `LITELLM_PORT`, update the `-p` flag in the `docker run` command accordingly.

Example using an `env` file:

```bash
cp litellm.env.example litellm.env
# Edit litellm.env and set your API keys, then:
docker run \
    --name litellm \
    --restart=always \
    -v litellm-data:/etc/litellm \
    -v ./litellm.env:/litellm.env:ro \
    -p 4000:4000/tcp \
    -d hwdsl2/litellm-server
```

The env file is bind-mounted into the container, so changes are picked up on every restart without recreating the container.

## Model management

Use `docker exec` to manage models with the `litellm_manage` helper script. Models are stored in `config.yaml` inside the Docker volume and persist across container restarts.

**Note:** `--addmodel` and `--removemodel` write to `config.yaml` and automatically restart the proxy to apply the change.

When `LITELLM_OLLAMA_BASE_URL` is set, the container keeps both default Ollama aliases in `config.yaml`: `ollama/llama3.2:3b` for backward compatibility and `ollama-chat/llama3.2:3b` for chat-native Ollama behavior. Use the `ollama-chat/...` alias for streaming tool calls.

**List configured models:**

```bash
docker exec litellm litellm_manage --listmodels
```

**Add a model with an API key:**

```bash
# OpenAI
docker exec litellm litellm_manage --addmodel openai/gpt-4o --key sk-...

# Anthropic
docker exec litellm litellm_manage --addmodel anthropic/claude-3-6-sonnet-latest --key sk-ant-...

# Groq
docker exec litellm litellm_manage --addmodel groq/llama-3.3-70b-versatile --key gsk_...

# Add with a custom display name (alias)
docker exec litellm litellm_manage --addmodel openai/gpt-4o --key sk-... --alias my-gpt4

# Mark a model as function-calling capable
docker exec litellm litellm_manage \
  --addmodel ollama_chat/llama3.2:3b \
  --alias ollama-chat/llama3.2:3b \
  --base-url http://host.docker.internal:11434 \
  --supports-function-calling
```

**Add a local Ollama model:**

```bash
# Connect to Ollama running on the Docker host
docker exec litellm litellm_manage \
  --addmodel ollama/llama3.2:3b \
  --base-url http://host.docker.internal:11434
```

For Ollama models that need native chat behavior or streaming tool calls, use the `ollama_chat/...` provider model with a user-facing alias such as `ollama-chat/llama3.2:3b`.

**Remove a model** (use the `id` field from `--listmodels`):

```bash
docker exec litellm litellm_manage --removemodel <model_id>
```

**Show the master key** (if you need to look it up):

```bash
# Full output with endpoint info
docker exec litellm litellm_manage --showkey

# Key only (for scripting — no IP or endpoint info displayed)
docker exec litellm litellm_manage --getkey
```

## MCP Gateway integration

Set `LITELLM_MCP_URL` (and optionally `LITELLM_MCP_API_KEY`) in your `litellm.env` file to automatically wire LiteLLM to an MCP Gateway, so AI clients can call MCP tools directly through the LiteLLM proxy.

When `LITELLM_MCP_URL` is set, an `mcp_servers:` block is injected into `config.yaml` on every container start — no manual YAML editing required.

**Wire to an MCP Gateway:**

```bash
# In litellm.env:
LITELLM_MCP_URL=http://mcp:3000/mcp
LITELLM_MCP_API_KEY=mcp-xxxx...   # get with: docker exec mcp mcp_manage --showkey
```

After setting these values, restart the container:

```bash
docker compose restart litellm
# or: docker restart litellm
```

**Manage MCP servers with `litellm_manage`:**

```bash
# List configured MCP servers
docker exec litellm litellm_manage --listmcp

# Add an MCP server manually
docker exec litellm litellm_manage --addmcp my-gateway http://mcp:3000/mcp --key mcp-xxxx

# Remove an MCP server
docker exec litellm litellm_manage --removemcp my-gateway
```

**Note:** `--addmcp` and `--removemcp` write to `config.yaml` and automatically restart the proxy. MCP servers added via `LITELLM_MCP_URL` are named `docker_mcp_gateway` in the config and can be managed with `--removemcp docker_mcp_gateway`.

## Virtual key management

Virtual keys are scoped API keys you can issue to users or applications. Each key can optionally restrict which models it may access, set a maximum spend budget, and have an expiry. Virtual keys require a PostgreSQL database, which is included in the default `docker-compose.yml`.

**Create a virtual key:**

```bash
# Basic key (no restrictions)
docker exec litellm litellm_manage --createkey

# Key with alias, model restrictions, budget, and expiry
docker exec litellm litellm_manage --createkey \
  --alias dev-key \
  --models gpt-4o,claude-3-6-sonnet \
  --budget 20.0 \
  --expires 30d
```

**List all virtual keys:**

```bash
docker exec litellm litellm_manage --listkeys
```

**Delete a virtual key:**

```bash
docker exec litellm litellm_manage --deletekey sk-...
```

## Using the proxy with OpenAI SDK

Point apps that use the OpenAI SDK at your proxy by setting two environment variables:

```bash
export OPENAI_API_KEY="<your-master-key>"
export OPENAI_BASE_URL="http://<server-ip>:4000"
```

For Python:

```python
from openai import OpenAI

client = OpenAI(
    api_key="<your-master-key>",
    base_url="http://<server-ip>:4000",
)

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Hello!"}],
)
print(response.choices[0].message.content)
```

The proxy is compatible with any tool or library that supports the OpenAI API format.

## Persistent data

All proxy data is stored in the Docker volume (`/etc/litellm` inside the container):

```
/etc/litellm/
├── config.yaml       # Proxy configuration and model list (created once, preserved across restarts)
├── .master_key       # Master API key (auto-generated, or synced from LITELLM_MASTER_KEY)
├── .initialized      # First-run marker
└── .db_configured    # Present when LITELLM_DATABASE_URL is set (used by litellm_manage)
```

Back up the Docker volume to preserve your master key and configured models.

## Using docker-compose

```bash
cp litellm.env.example litellm.env
# Edit litellm.env and set your API keys, then:
docker compose up -d
docker logs litellm
```

Fresh Compose installs generate a random PostgreSQL password automatically and store it in the `litellm-secrets` volume. Existing default installs continue to use the legacy `litellm` database password for compatibility. If you previously customized the database password, set `LITELLM_POSTGRES_PASSWORD` in your shell environment to that password before running `docker compose up -d`, or keep an explicit `LITELLM_DATABASE_URL` override in `litellm.env`.

When upgrading an existing checkout, run `docker compose pull` before `docker compose up -d` so the LiteLLM image supports `LITELLM_POSTGRES_PASSWORD_FILE`.

Example `docker-compose.yml` (already included):

```yaml
services:
  litellm-init:
    image: alpine:3.24
    container_name: litellm-init
    restart: "no"
    environment:
      - LITELLM_POSTGRES_PASSWORD=${LITELLM_POSTGRES_PASSWORD:-}
    volumes:
      - litellm-db:/var/lib/postgresql:ro
      - litellm-secrets:/var/lib/litellm-secrets
      - ./scripts/litellm-init.sh:/usr/local/bin/litellm-init.sh:ro
    entrypoint: ["/bin/sh", "/usr/local/bin/litellm-init.sh"]

  db:
    image: postgres:18
    container_name: litellm-db
    restart: always
    environment:
      POSTGRES_USER: litellm
      POSTGRES_PASSWORD_FILE: /var/lib/litellm-secrets/postgres_password
      POSTGRES_DB: litellm
    volumes:
      - litellm-db:/var/lib/postgresql
      - litellm-secrets:/var/lib/litellm-secrets:ro
    depends_on:
      litellm-init:
        condition: service_completed_successfully
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U litellm"]
      interval: 15s
      timeout: 5s
      retries: 5

  litellm:
    image: hwdsl2/litellm-server
    container_name: litellm
    restart: always
    ports:
      - "4000:4000/tcp"  # For a host-based reverse proxy, change to "127.0.0.1:4000:4000/tcp"
    environment:
      - LITELLM_POSTGRES_PASSWORD_FILE=/var/lib/litellm-secrets/postgres_password
    volumes:
      - litellm-data:/etc/litellm
      - litellm-secrets:/var/lib/litellm-secrets:ro
      - ./litellm.env:/litellm.env:ro
    depends_on:
      db:
        condition: service_healthy

volumes:
  litellm-data:
    name: litellm-data
  litellm-secrets:
    name: litellm-secrets
  litellm-db:
    name: litellm-db
```

**Note:** For internet-facing deployments, using a [reverse proxy](#using-a-reverse-proxy) to add HTTPS is **strongly recommended**. In that case, also change `"4000:4000/tcp"` to `"127.0.0.1:4000:4000/tcp"` in `docker-compose.yml`, to prevent direct access to the unencrypted port.

## Using a reverse proxy

For internet-facing deployments, place a reverse proxy in front of LiteLLM to handle HTTPS termination. The server works without HTTPS on a local or trusted network, but HTTPS is recommended when the API endpoint is exposed to the internet.

Use one of the following addresses to reach the LiteLLM container from your reverse proxy:

- **`litellm:4000`** — if your reverse proxy runs as a container in the **same Docker network** as LiteLLM (e.g. defined in the same `docker-compose.yml`).
- **`127.0.0.1:4000`** — if your reverse proxy runs **on the host** and port `4000` is published (the default `docker-compose.yml` publishes it).

**Example with [Caddy](https://caddyserver.com/docs/) ([Docker image](https://hub.docker.com/_/caddy))** (automatic TLS via Let's Encrypt, reverse proxy in the same Docker network):

`Caddyfile`:
```
litellm.example.com {
  reverse_proxy litellm:4000
}
```

**Example with nginx** (reverse proxy on the host):

```nginx
server {
    listen 443 ssl;
    server_name litellm.example.com;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass         http://127.0.0.1:4000;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_buffering    off;
    }
}
```

After setting up a reverse proxy, set `LITELLM_HOST=litellm.example.com` in your `env` file so that the correct endpoint URL is shown in the startup logs and `litellm_manage --showkey` output.

The auto-generated master API key is required for all API requests. Keep it secure when the server is accessible from the public internet.

## Update Docker image

To update the Docker image and container, first [download](#download) the latest version:

```bash
docker pull hwdsl2/litellm-server
```

If the Docker image is already up to date, you should see:

```
Status: Image is up to date for hwdsl2/litellm-server:latest
```

Otherwise, it will download the latest version. Remove and re-create the container:

```bash
docker rm -f litellm
# Then re-run the docker run command from Quick start with the same volume and port.
```

Your data is preserved in the `litellm-data` volume.

## Using with other AI services

LiteLLM can be used as the AI gateway in a broader self-hosted AI setup.

For full and lightweight Docker Compose stacks, manual `docker run` examples, and voice/RAG/MCP pipeline examples with Kokoro, Embeddings, LiteLLM, Ollama, Docling, and MCP Gateway, see [Self-Hosted AI Stack](https://github.com/hwdsl2/self-hosted-ai-stack).

## Technical details

- Base image: `python:3.12-slim` (Debian)
- Runtime: Python 3 (virtual environment at `/opt/venv`)
- LiteLLM: latest `litellm[proxy]` from PyPI
- Data directory: `/etc/litellm` (Docker volume)
- Model storage: `config.yaml` inside the volume — created on first start, preserved on restarts
- Proxy management REST API: runs on the same port as the proxy
- Built-in UI: available at `http://<server>:<port>/ui` — log in with username `admin` and your master key as the password

## License

**Note:** The software components inside the pre-built image (such as LiteLLM and its dependencies) are under the respective licenses chosen by their respective copyright holders. As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.

Copyright (C) 2026 Lin Song   
This work is licensed under the [MIT License](https://opensource.org/licenses/MIT).

**LiteLLM** is Copyright (C) 2023 Berri AI, and is distributed under the [MIT License](https://github.com/BerriAI/litellm/blob/main/LICENSE).

This project is an independent Docker setup for LiteLLM and is not affiliated with, endorsed by, or sponsored by Berri AI, the creators of LiteLLM.
