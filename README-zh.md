[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# LiteLLM AI 网关 Docker 镜像

[![Build Status](https://github.com/hwdsl2/docker-litellm/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-litellm/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

运行 [LiteLLM](https://github.com/BerriAI/litellm) AI 网关代理的 Docker 镜像。在 100+ 个大型语言模型（LLM）提供商前面提供统一的 OpenAI 兼容 API 端点。基于 Debian (python:3.12-slim)。简单、私密、可自托管。

**功能特性：**

- 首次启动时自动生成主 API 密钥和配置
- 自动为环境文件中设置的提供商 API 密钥添加对应模型
- 通过辅助脚本（`litellm_manage`）管理模型
- 无需数据库 — 模型配置以普通 YAML 文件形式存储在 Docker 卷中
- OpenAI 兼容 API — 只需修改一行配置，即可将任何 OpenAI SDK 或应用程序指向此代理
- 支持 OpenAI、Anthropic、Groq、Gemini、Ollama 及 [100+ 其他提供商](https://docs.litellm.ai/docs/providers)
- 通过 [GitHub Actions](https://github.com/hwdsl2/docker-litellm/actions/workflows/main.yml) 自动构建和发布
- 通过 Docker 卷持久化数据
- 多架构支持：`linux/amd64`、`linux/arm64`

**另提供：**

- AI/音频：[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md)、[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md)、[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh.md)、[Ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh.md)
- VPN：[WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-zh.md)、[OpenVPN](https://github.com/hwdsl2/docker-openvpn/blob/main/README-zh.md)、[IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-zh.md)、[Headscale](https://github.com/hwdsl2/docker-headscale/blob/main/README-zh.md)

**提示：** Whisper、Kokoro、Embeddings、LiteLLM 和 Ollama 可以[配合使用](#与其他-ai-服务配合使用)，在您自己的服务器上搭建完整的私密 AI 系统。

## 快速开始

**第一步。** 启动 LiteLLM 代理：

```bash
docker run \
    --name litellm \
    --restart=always \
    -v litellm-data:/etc/litellm \
    -p 4000:4000/tcp \
    -d hwdsl2/litellm-server
```

首次启动时，服务器会自动生成主 API 密钥并创建配置。主密钥会打印到容器日志中。

**注：** 如需面向互联网的部署，**强烈建议**使用[反向代理](#使用反向代理)来添加 HTTPS。此时，还应将上述 `docker run` 命令中的 `-p 4000:4000/tcp` 替换为 `-p 127.0.0.1:4000:4000/tcp`，以防止从外部直接访问未加密端口。

**第二步。** 查看容器日志以获取主密钥：

```bash
docker logs litellm
```

主密钥显示在标有 **LiteLLM proxy master key** 的方框中。请复制此密钥 — 您将使用它来验证所有 API 请求。

**注：** 主密钥仅在首次运行设置期间打印。如需随时再次显示，请运行：

```bash
docker exec litellm litellm_manage --showkey
```

**第三步。** 使用 OpenAI 兼容请求测试代理：

```bash
# 列出可用模型
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer <您的主密钥>"

# 发送聊天请求（添加模型后 — 见下文）
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer <您的主密钥>" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o", "messages": [{"role": "user", "content": "你好！"}]}'
```

**注：** 上述聊天请求命令需要先配置至少一个模型才能使用。请参见[模型管理](#模型管理)。

## 系统要求

- 安装了 Docker 的 Linux 服务器（本地或云端）
- 至少一个 LLM 提供商 API 密钥（OpenAI、Anthropic、Groq 等）**或** 本地运行的 [Ollama](https://ollama.com) 实例
- TCP 端口 4000（或您配置的端口）已开放

不需要 LLM 提供商密钥也可以启动代理 — 服务器可以在模型列表为空的情况下成功启动。随时可以使用 `litellm_manage` 添加模型。

如需面向互联网的部署，请参阅[使用反向代理](#使用反向代理)以添加 HTTPS。

## 下载

从 [Docker Hub 镜像仓库](https://hub.docker.com/r/hwdsl2/litellm-server/) 获取可信构建：

```bash
docker pull hwdsl2/litellm-server
```

或者，您也可以从 [Quay.io](https://quay.io/repository/hwdsl2/litellm-server) 下载：

```bash
docker pull quay.io/hwdsl2/litellm-server
docker image tag quay.io/hwdsl2/litellm-server hwdsl2/litellm-server
```

支持的平台：`linux/amd64` 和 `linux/arm64`。

## 环境变量

所有变量均为可选。如未设置，将自动使用安全默认值。

此 Docker 镜像使用以下变量，可在 `env` 文件中声明（参见[示例](litellm.env.example)）：

| 变量 | 说明 | 默认值 |
|---|---|---|
| `LITELLM_MASTER_KEY` | 代理的主 API 密钥 | 自动生成 |
| `LITELLM_PORT` | 代理的 TCP 端口（1–65535） | `4000` |
| `LITELLM_HOST` | 启动信息和 `--showkey` 输出中显示的主机名或 IP | 自动检测 |
| `LITELLM_LOG_LEVEL` | 日志级别：`DEBUG`、`INFO`、`WARNING`、`ERROR`、`CRITICAL` | `INFO` |
| `LITELLM_OPENAI_API_KEY` | OpenAI API 密钥 — 自动添加 `gpt-4o`、`gpt-4o-mini` | *(未设置)* |
| `LITELLM_ANTHROPIC_API_KEY` | Anthropic API 密钥 — 自动添加 `claude-3-6-sonnet`（最新版） | *(未设置)* |
| `LITELLM_GROQ_API_KEY` | Groq API 密钥 — 自动添加 `llama-3.3-70b` | *(未设置)* |
| `LITELLM_GEMINI_API_KEY` | Google Gemini API 密钥 — 自动添加 `gemini-2.0-flash` | *(未设置)* |
| `LITELLM_OLLAMA_BASE_URL` | Ollama 基础 URL — 自动添加 `ollama/llama3.2` | *(未设置)* |
| `LITELLM_DATABASE_URL` | PostgreSQL URL — 启用虚拟密钥管理 | *(未设置)* |

**注：** 在 `env` 文件中，可以用单引号括住变量值，例如 `VAR='值'`。不要在 `=` 两边添加空格。如果更改了 `LITELLM_PORT`，请相应更新 `docker run` 命令中的 `-p` 参数。

使用 `env` 文件的示例：

```bash
cp litellm.env.example litellm.env
# 编辑 litellm.env 并设置您的 API 密钥，然后：
docker run \
    --name litellm \
    --restart=always \
    -v litellm-data:/etc/litellm \
    -v ./litellm.env:/litellm.env:ro \
    -p 4000:4000/tcp \
    -d hwdsl2/litellm-server
```

env 文件以绑定挂载方式挂载到容器中，因此每次重启容器时都会读取最新的变量，无需重新创建容器。

## 模型管理

使用 `docker exec` 通过 `litellm_manage` 辅助脚本管理模型。模型存储在 Docker 卷内的 `config.yaml` 中，容器重启后仍然保留。

**注：** `--addmodel` 和 `--removemodel` 会写入 `config.yaml` 并自动重启代理以应用更改。

**列出已配置的模型：**

```bash
docker exec litellm litellm_manage --listmodels
```

**添加带有 API 密钥的模型：**

```bash
# OpenAI
docker exec litellm litellm_manage --addmodel openai/gpt-4o --key sk-...

# Anthropic
docker exec litellm litellm_manage --addmodel anthropic/claude-3-6-sonnet-latest --key sk-ant-...

# Groq
docker exec litellm litellm_manage --addmodel groq/llama-3.3-70b-versatile --key gsk_...

# 添加自定义显示名称（别名）
docker exec litellm litellm_manage --addmodel openai/gpt-4o --key sk-... --alias my-gpt4
```

**添加本地 Ollama 模型：**

```bash
# 连接到 Docker 宿主机上运行的 Ollama
docker exec litellm litellm_manage \
  --addmodel ollama/llama3.2 \
  --base-url http://host.docker.internal:11434
```

**删除模型**（使用 `--listmodels` 中的 `id` 字段）：

```bash
docker exec litellm litellm_manage --removemodel <模型ID>
```

**显示主密钥**（如需查询）：

```bash
docker exec litellm litellm_manage --showkey
```

## 虚拟密钥管理

虚拟密钥是可颁发给用户或应用程序的受限 API 密钥。每个密钥可以选择性地限制可访问的模型、设置最大支出预算以及设置过期时间。虚拟密钥需要 PostgreSQL 数据库 —— 请在启动容器前在 `env` 文件中设置 `LITELLM_DATABASE_URL`。

**创建虚拟密钥：**

```bash
# 基本密钥（无限制）
docker exec litellm litellm_manage --createkey

# 带别名、模型限制、预算和过期时间的密钥
docker exec litellm litellm_manage --createkey \
  --alias dev-key \
  --models gpt-4o,claude-3-6-sonnet \
  --budget 20.0 \
  --expires 30d
```

**列出所有虚拟密钥：**

```bash
docker exec litellm litellm_manage --listkeys
```

**删除虚拟密钥：**

```bash
docker exec litellm litellm_manage --deletekey sk-...
```

## 与 OpenAI SDK 一起使用

通过设置两个环境变量，将任何使用 OpenAI SDK 的应用程序指向您的代理：

```bash
export OPENAI_API_KEY="<您的主密钥>"
export OPENAI_BASE_URL="http://<服务器IP>:4000"
```

Python 示例：

```python
from openai import OpenAI

client = OpenAI(
    api_key="<您的主密钥>",
    base_url="http://<服务器IP>:4000",
)

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "你好！"}],
)
print(response.choices[0].message.content)
```

## 持久化数据

所有代理数据存储在 Docker 卷中（容器内的 `/etc/litellm`）：

```
/etc/litellm/
├── config.yaml       # 代理配置和模型列表（创建一次，重启后保留）
├── .master_key       # 主 API 密钥（自动生成，或从 LITELLM_MASTER_KEY 同步）
├── .initialized      # 首次运行标记
├── .server_addr      # 缓存的服务器主机名或 IP（供 litellm_manage --showkey 使用）
└── .db_configured    # 设置了 LITELLM_DATABASE_URL 时存在（供 litellm_manage 使用）
```

备份 Docker 卷以保留您的主密钥和已配置的模型。

## 使用 docker-compose

```bash
cp litellm.env.example litellm.env
# 编辑 litellm.env 并设置您的 API 密钥，然后：
docker compose up -d
docker logs litellm
```

示例 `docker-compose.yml`（已包含在内）：

```yaml
services:
  litellm:
    image: hwdsl2/litellm-server
    container_name: litellm
    restart: always
    ports:
      - "4000:4000/tcp"  # For a host-based reverse proxy, change to "127.0.0.1:4000:4000/tcp"
    volumes:
      - litellm-data:/etc/litellm
      - ./litellm.env:/litellm.env:ro

volumes:
  litellm-data:
```

**注：** 如需面向互联网的部署，**强烈建议**使用[反向代理](#使用反向代理)来添加 HTTPS。此时，还应将 `docker-compose.yml` 中的 `"4000:4000/tcp"` 改为 `"127.0.0.1:4000:4000/tcp"`，以防止从外部直接访问未加密端口。

## 使用反向代理

对于面向互联网的部署，您可以在 LiteLLM 代理前面放置反向代理来处理 HTTPS 终止。在本地或受信任的网络中，代理无需 HTTPS 即可工作，但当 API 端点暴露在互联网上时，建议使用 HTTPS。

使用以下地址之一，从反向代理访问 LiteLLM 容器：

- **`litellm:4000`** — 如果反向代理作为容器运行在与 LiteLLM **相同的 Docker 网络**中（例如定义在同一个 `docker-compose.yml` 中）。Docker 会自动解析容器名称。
- **`127.0.0.1:4000`** — 如果反向代理**在宿主机上**运行，且端口 `4000` 已发布（默认的 `docker-compose.yml` 会发布此端口）。

**使用 [Caddy](https://caddyserver.com/docs/)（[Docker 镜像](https://hub.docker.com/_/caddy)）的示例**（通过 Let's Encrypt 自动配置 TLS，反向代理在相同的 Docker 网络中运行）：

`Caddyfile`：
```
litellm.example.com {
  reverse_proxy litellm:4000
}
```

**使用 nginx 的示例**（反向代理在宿主机上运行）：

```nginx
server {
  listen 443 ssl;
  server_name litellm.example.com;

  ssl_certificate     /path/to/cert.pem;
  ssl_certificate_key /path/to/key.pem;

  location / {
    proxy_pass http://127.0.0.1:4000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 300s;
    proxy_buffering off;
  }
}
```

设置反向代理后，在 `env` 文件中设置 `LITELLM_HOST=litellm.example.com`，以便在启动日志和 `litellm_manage --showkey` 输出中显示正确的端点 URL。

自动生成的主 API 密钥是所有 API 请求所必需的。当服务器可从公网访问时，请妥善保管该密钥。

## 更新 Docker 镜像

要更新 Docker 镜像和容器，请先[下载](#下载)最新版本：

```bash
docker pull hwdsl2/litellm-server
```

如果 Docker 镜像已是最新版本，您将看到：

```
Status: Image is up to date for hwdsl2/litellm-server:latest
```

否则将下载最新版本。删除并重新创建容器：

```bash
docker rm -f litellm
# 然后使用相同的卷和端口重新运行快速开始中的 docker run 命令。
```

您的数据保存在 `litellm-data` 卷中。

## 与其他 AI 服务配合使用

[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md)、[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh.md)、[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md)、[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md) 和 [Ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh.md) 镜像可以组合使用，在您自己的服务器上搭建完整的私密 AI 系统——从语音输入/输出到检索增强生成（RAG）。Whisper、Kokoro 和 Embeddings 完全在本地运行。Ollama 在本地运行所有 LLM 推理，无需向第三方发送数据。如果您将 LiteLLM 配置为使用外部提供商（例如 OpenAI、Anthropic），您的数据将被发送至这些提供商处理。

```mermaid
graph LR
    D["📄 文档"] -->|向量化| E["Embeddings<br/>(文本转向量)"]
    E -->|存储| VDB["向量数据库<br/>(Qdrant, Chroma)"]
    A["🎤 语音输入"] -->|转录| W["Whisper<br/>(语音转文本)"]
    W -->|查询| E
    VDB -->|上下文| L["LiteLLM<br/>(AI 网关)"]
    W -->|文本| L
    L -->|路由到| O["Ollama<br/>(本地 LLM)"]
    L -->|响应| T["Kokoro TTS<br/>(文本转语音)"]
    T --> B["🔊 语音输出"]
```

| 服务 | 功能 | 默认端口 |
|---|---|---|
| **[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh.md)** | 将文本转换为向量，用于语义搜索和 RAG | `8000` |
| **[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md)** | 将语音音频转录为文本 | `9000` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md)** | AI 网关——将请求路由至 OpenAI、Anthropic、Ollama 及 100+ 其他提供商 | `4000` |
| **[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md)** | 将文本转换为自然语音 | `8880` |
| **[Ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh.md)** | 运行本地 LLM 模型（llama3、qwen、mistral 等） | `11434` |

<details>
<summary><strong>语音对话示例</strong></summary>

将语音问题转录为文本，从大型语言模型获取回答，并转换为语音输出：

```bash
# 第一步：将语音音频转录为文本（Whisper）
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -F file=@question.mp3 -F model=whisper-1 | jq -r .text)

# 第二步：将文本发送给大型语言模型并获取响应（LiteLLM）
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer <your-litellm-key>" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"gpt-4o\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# 第三步：将响应转换为语音（Kokoro TTS）
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3
```

</details>

<details>
<summary><strong>RAG 检索增强生成示例</strong></summary>

对文档进行向量化以实现语义检索，并将检索到的上下文发送给大型语言模型进行问答：

```bash
# 第一步：对文档片段进行向量化并存入向量数据库
curl -s http://localhost:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "Docker simplifies deployment by packaging apps in containers.", "model": "text-embedding-ada-002"}' \
    | jq '.data[0].embedding'
# → 将返回的向量连同原文一起存入 Qdrant、Chroma、pgvector 等向量数据库。

# 第二步：查询时，对问题进行向量化并从向量数据库检索最相关的文档片段，
#          然后将问题和检索到的上下文发送给 LiteLLM 以获取 LLM 回答。
curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer <your-litellm-key>" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "gpt-4o",
      "messages": [
        {"role": "system", "content": "请仅根据所提供的上下文进行回答。"},
        {"role": "user", "content": "Docker 的作用是什么？\n\n上下文：Docker 通过将应用打包为容器来简化部署流程。"}
      ]
    }' \
    | jq -r '.choices[0].message.content'
```

</details>

<details>
<summary><strong>完整技术栈 docker-compose 示例</strong></summary>

使用一条命令部署所有服务。LiteLLM 通过共享 Docker 网络内部连接到 Ollama — 在 `litellm.env` 中设置 `LITELLM_OLLAMA_BASE_URL=http://ollama:11434`。

**资源要求：** 同时运行所有服务至少需要 8 GB 内存（使用小型模型）。对于较大的 LLM 模型（8B+），建议 32 GB 或更多。您可以注释掉不需要的服务以减少内存使用。

```yaml
services:
  ollama:
    image: hwdsl2/ollama-server
    container_name: ollama
    restart: always
    # ports:
    #   - "11434:11434/tcp"  # 取消注释以直接访问 Ollama
    volumes:
      - ollama-data:/var/lib/ollama
      - ./ollama.env:/ollama.env:ro

  litellm:
    image: hwdsl2/litellm-server
    container_name: litellm
    restart: always
    ports:
      - "4000:4000/tcp"
    volumes:
      - litellm-data:/etc/litellm
      - ./litellm.env:/litellm.env:ro

  embeddings:
    image: hwdsl2/embeddings-server
    container_name: embeddings
    restart: always
    ports:
      - "8000:8000/tcp"
    volumes:
      - embeddings-data:/var/lib/embeddings
      - ./embed.env:/embed.env:ro

  whisper:
    image: hwdsl2/whisper-server
    container_name: whisper
    restart: always
    ports:
      - "9000:9000/tcp"
    volumes:
      - whisper-data:/var/lib/whisper
      - ./whisper.env:/whisper.env:ro

  kokoro:
    image: hwdsl2/kokoro-server
    container_name: kokoro
    restart: always
    ports:
      - "8880:8880/tcp"
    volumes:
      - kokoro-data:/var/lib/kokoro
      - ./kokoro.env:/kokoro.env:ro

volumes:
  ollama-data:
  litellm-data:
  embeddings-data:
  whisper-data:
  kokoro-data:
```

如需 NVIDIA GPU 加速，将 ollama、whisper 和 kokoro 的镜像标签改为 `:cuda`，并为这些服务添加以下配置：

```yaml
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

</details>

## 技术细节

- 基础镜像：`python:3.12-slim`（Debian）
- 运行时：Python 3（虚拟环境位于 `/opt/venv`）
- LiteLLM：来自 PyPI 的最新版 `litellm[proxy]`
- 数据目录：`/etc/litellm`（Docker 数据卷）
- 模型存储：数据卷内的 `config.yaml` —— 首次启动时创建，重启后保留
- 代理管理 REST API：与代理运行在同一端口
- 内置 UI：可通过 `http://<服务器>:<端口>/ui` 访问

## 授权协议

**注：** 预构建镜像中的软件组件（如 LiteLLM 及其依赖项）遵循各自版权持有者所选择的相应许可证。对于任何预构建镜像的使用，镜像用户有责任确保其使用符合镜像中所包含的所有软件的相关许可证。

版权所有 (C) 2026 Lin Song   
本作品依据 [MIT 许可证](https://opensource.org/licenses/MIT)授权。

**LiteLLM** 版权所有 (C) 2023 Berri AI，依照 [MIT 许可证](https://github.com/BerriAI/litellm/blob/main/LICENSE)分发。

本项目是一个用于 LiteLLM 的独立 Docker 部署方案，与 LiteLLM 的开发者 Berri AI 无任何关联，也未获得其认可或赞助。