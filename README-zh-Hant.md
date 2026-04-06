[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# LiteLLM AI 閘道 Docker 映像

[![Build Status](https://github.com/hwdsl2/docker-litellm/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-litellm/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

執行 [LiteLLM](https://github.com/BerriAI/litellm) AI 閘道代理的 Docker 映像。在 100 個以上大型語言模型（LLM）提供商前面提供統一的 OpenAI 相容 API 端點。基於 Debian (python:3.12-slim)。簡單、私密、可自行託管。

- 首次啟動時自動產生主 API 金鑰和設定檔
- 自動為環境檔案中設定的提供商 API 金鑰新增對應模型
- 透過輔助腳本（`litellm_manage`）管理模型
- 無需資料庫 — 模型設定以純 YAML 檔案形式儲存於 Docker 磁碟區中
- OpenAI 相容 API — 只需修改一行設定，即可將任何 OpenAI SDK 或應用程式指向此代理
- 支援 OpenAI、Anthropic、Groq、Gemini、Ollama 及 [100 個以上其他提供商](https://docs.litellm.ai/docs/providers)
- 透過 [GitHub Actions](https://github.com/hwdsl2/docker-litellm/actions/workflows/main.yml) 自動建置和發布
- 透過 Docker 磁碟區持久化資料
- 多架構支援：`linux/amd64`、`linux/arm64`

**另提供：** [WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-zh-Hant.md)、[OpenVPN](https://github.com/hwdsl2/docker-openvpn/blob/main/README-zh-Hant.md)、[IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-zh-Hant.md) 與 [Headscale](https://github.com/hwdsl2/docker-headscale/blob/main/README-zh-Hant.md) 的 Docker 映像。

## 快速開始

**第一步。** 啟動 LiteLLM 代理：

```bash
docker run \
    --name litellm \
    --restart=always \
    -v litellm-data:/etc/litellm \
    -p 4000:4000/tcp \
    -d hwdsl2/litellm-server
```

首次啟動時，伺服器會自動產生主 API 金鑰並建立設定檔。主金鑰會列印到容器日誌中。

**注：** 如需面向網際網路的部署，**強烈建議**使用[反向代理](#使用反向代理)來新增 HTTPS。此時，還應將上述 `docker run` 命令中的 `-p 4000:4000/tcp` 替換為 `-p 127.0.0.1:4000:4000/tcp`，以防止從外部直接存取未加密連接埠。

**第二步。** 查看容器日誌以取得主金鑰：

```bash
docker logs litellm
```

主金鑰顯示在標有 **LiteLLM proxy master key** 的方框中。請複製此金鑰 — 您將使用它來驗證所有 API 請求。

**注：** 主金鑰僅在首次執行設定期間列印。如需隨時再次顯示，請執行：

```bash
docker exec litellm litellm_manage --showkey
```

**第三步。** 使用 OpenAI 相容請求測試代理：

```bash
# 列出可用模型
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer <您的主金鑰>"

# 傳送聊天請求（新增模型後 — 見下文）
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer <您的主金鑰>" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o", "messages": [{"role": "user", "content": "你好！"}]}'
```

**注：** 上述聊天請求命令需要先設定至少一個模型才能使用。請參見[模型管理](#模型管理)。

## 系統需求

- 已安裝 Docker 的 Linux 伺服器（本地端或雲端）
- 至少一個 LLM 提供商 API 金鑰（OpenAI、Anthropic、Groq 等）**或** 本機執行的 [Ollama](https://ollama.com) 實例
- TCP 連接埠 4000（或您設定的連接埠）已開放

不需要 LLM 提供商金鑰也可以啟動代理 — 伺服器可以在模型清單為空的情況下成功啟動。隨時可以使用 `litellm_manage` 新增模型。

如需面向網際網路的部署，請參閱[使用反向代理](#使用反向代理)以新增 HTTPS。

## 下載

從 [Docker Hub 映像倉庫](https://hub.docker.com/r/hwdsl2/litellm-server/) 取得可信任的建置版本：

```bash
docker pull hwdsl2/litellm-server
```

或者，您也可以從 [Quay.io](https://quay.io/repository/hwdsl2/litellm-server) 下載：

```bash
docker pull quay.io/hwdsl2/litellm-server
docker image tag quay.io/hwdsl2/litellm-server hwdsl2/litellm-server
```

支援的平台：`linux/amd64` 和 `linux/arm64`。

## 環境變數

所有變數均為可選。如未設定，將自動使用安全預設值。

此 Docker 映像使用以下變數，可在 `env` 檔案中宣告（參見[範例](litellm.env.example)）：

| 變數 | 說明 | 預設值 |
|---|---|---|
| `LITELLM_MASTER_KEY` | 代理的主 API 金鑰 | 自動產生 |
| `LITELLM_PORT` | 代理的 TCP 連接埠（1–65535） | `4000` |
| `LITELLM_HOST` | 啟動資訊和 `--showkey` 輸出中顯示的主機名稱或 IP | 自動偵測 |
| `LITELLM_LOG_LEVEL` | 日誌級別：`DEBUG`、`INFO`、`WARNING`、`ERROR`、`CRITICAL` | `INFO` |
| `LITELLM_OPENAI_API_KEY` | OpenAI API 金鑰 — 自動新增 `gpt-4o`、`gpt-4o-mini` | *(未設定)* |
| `LITELLM_ANTHROPIC_API_KEY` | Anthropic API 金鑰 — 自動新增 `claude-3-6-sonnet`（最新版） | *(未設定)* |
| `LITELLM_GROQ_API_KEY` | Groq API 金鑰 — 自動新增 `llama-3.3-70b` | *(未設定)* |
| `LITELLM_GEMINI_API_KEY` | Google Gemini API 金鑰 — 自動新增 `gemini-2.0-flash` | *(未設定)* |
| `LITELLM_OLLAMA_BASE_URL` | Ollama 基礎 URL — 自動新增 `ollama/llama3.2` | *(未設定)* |
| `LITELLM_DATABASE_URL` | PostgreSQL URL — 啟用虛擬金鑰管理 | *(未設定)* |

**注：** 在 `env` 檔案中，可以用單引號括住變數值，例如 `VAR='值'`。不要在 `=` 兩側新增空格。如果更改了 `LITELLM_PORT`，請相應更新 `docker run` 命令中的 `-p` 參數。

使用 `env` 檔案的範例：

```bash
cp litellm.env.example litellm.env
# 編輯 litellm.env 並設定您的 API 金鑰，然後：
docker run \
    --name litellm \
    --restart=always \
    -v litellm-data:/etc/litellm \
    -v ./litellm.env:/litellm.env:ro \
    -p 4000:4000/tcp \
    -d hwdsl2/litellm-server
```

env 檔案以綁定掛載方式掛載到容器中，因此每次重新啟動容器時都會讀取最新的變數，無需重新建立容器。

## 模型管理

使用 `docker exec` 透過 `litellm_manage` 輔助腳本管理模型。模型儲存在 Docker 磁碟區內的 `config.yaml` 中，容器重新啟動後仍然保留。

**注：** `--addmodel` 和 `--removemodel` 會寫入 `config.yaml` 並自動重新啟動代理以套用變更。

**列出已設定的模型：**

```bash
docker exec litellm litellm_manage --listmodels
```

**新增帶有 API 金鑰的模型：**

```bash
# OpenAI
docker exec litellm litellm_manage --addmodel openai/gpt-4o --key sk-...

# Anthropic
docker exec litellm litellm_manage --addmodel anthropic/claude-3-6-sonnet-latest --key sk-ant-...

# Groq
docker exec litellm litellm_manage --addmodel groq/llama-3.3-70b-versatile --key gsk_...

# 新增自訂顯示名稱（別名）
docker exec litellm litellm_manage --addmodel openai/gpt-4o --key sk-... --alias my-gpt4
```

**新增本機 Ollama 模型：**

```bash
# 連接到 Docker 主機上執行的 Ollama
docker exec litellm litellm_manage \
  --addmodel ollama/llama3.2 \
  --base-url http://host.docker.internal:11434
```

**刪除模型**（使用 `--listmodels` 中的 `id` 欄位）：

```bash
docker exec litellm litellm_manage --removemodel <模型ID>
```

**顯示主金鑰**（如需查詢）：

```bash
docker exec litellm litellm_manage --showkey
```

## 虛擬金鑰管理

虛擬金鑰是可頒發給使用者或應用程式的受限 API 金鑰。每個金鑰可以選擇性地限制可存取的模型、設定最大支出預算以及設定過期時間。虛擬金鑰需要 PostgreSQL 資料庫 —— 請在啟動容器前在 `env` 檔案中設定 `LITELLM_DATABASE_URL`。

**建立虛擬金鑰：**

```bash
# 基本金鑰（無限制）
docker exec litellm litellm_manage --createkey

# 帶別名、模型限制、預算和過期時間的金鑰
docker exec litellm litellm_manage --createkey \
  --alias dev-key \
  --models gpt-4o,claude-3-6-sonnet \
  --budget 20.0 \
  --expires 30d
```

**列出所有虛擬金鑰：**

```bash
docker exec litellm litellm_manage --listkeys
```

**刪除虛擬金鑰：**

```bash
docker exec litellm litellm_manage --deletekey sk-...
```

## 與 OpenAI SDK 一起使用

透過設定兩個環境變數，將任何使用 OpenAI SDK 的應用程式指向您的代理：

```bash
export OPENAI_API_KEY="<您的主金鑰>"
export OPENAI_BASE_URL="http://<伺服器IP>:4000"
```

Python 範例：

```python
from openai import OpenAI

client = OpenAI(
    api_key="<您的主金鑰>",
    base_url="http://<伺服器IP>:4000",
)

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "你好！"}],
)
print(response.choices[0].message.content)
```

## 持久化資料

所有代理資料儲存在 Docker 磁碟區中（容器內的 `/etc/litellm`）：

```
/etc/litellm/
├── config.yaml       # 代理設定檔和模型清單（建立一次，重新啟動後保留）
├── .master_key       # 主 API 金鑰（自動產生，或從 LITELLM_MASTER_KEY 同步）
├── .initialized      # 首次執行標記
├── .server_addr      # 快取的伺服器主機名稱或 IP（供 litellm_manage --showkey 使用）
└── .db_configured    # 設定了 LITELLM_DATABASE_URL 時存在（供 litellm_manage 使用）
```

備份 Docker 磁碟區以保留您的主金鑰和已設定的模型。

## 使用 docker-compose

```bash
cp litellm.env.example litellm.env
# 編輯 litellm.env 並設定您的 API 金鑰，然後：
docker compose up -d
docker logs litellm
```

範例 `docker-compose.yml`（已包含在內）：

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

**注：** 如需面向網際網路的部署，**強烈建議**使用[反向代理](#使用反向代理)來新增 HTTPS。此時，還應將 `docker-compose.yml` 中的 `"4000:4000/tcp"` 改為 `"127.0.0.1:4000:4000/tcp"`，以防止從外部直接存取未加密連接埠。

## 使用反向代理

對於面向網際網路的部署，您可以在 LiteLLM 代理前面放置反向代理來處理 HTTPS 終止。在本地端或受信任的網路中，代理無需 HTTPS 即可運作，但當 API 端點暴露在網際網路上時，建議使用 HTTPS。

使用以下其中一個位址，從反向代理存取 LiteLLM 容器：

- **`litellm:4000`** — 如果反向代理作為容器執行在與 LiteLLM **相同的 Docker 網路**中（例如定義在同一個 `docker-compose.yml` 中）。Docker 會自動解析容器名稱。
- **`127.0.0.1:4000`** — 如果反向代理**在主機上**執行，且連接埠 `4000` 已發布（預設的 `docker-compose.yml` 會發布此連接埠）。

**使用 [Caddy](https://caddyserver.com/docs/)（[Docker 映像](https://hub.docker.com/_/caddy)）的範例**（透過 Let's Encrypt 自動設定 TLS，反向代理在相同的 Docker 網路中執行）：

`Caddyfile`：
```
litellm.example.com {
  reverse_proxy litellm:4000
}
```

**使用 nginx 的範例**（反向代理在主機上執行）：

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

設定反向代理後，在 `env` 檔案中設定 `LITELLM_HOST=litellm.example.com`，以便在啟動日誌和 `litellm_manage --showkey` 輸出中顯示正確的端點 URL。

## 更新 Docker 映像

要更新 Docker 映像和容器，請先[下載](#下載)最新版本：

```bash
docker pull hwdsl2/litellm-server
```

如果 Docker 映像已是最新版本，您將看到：

```
Status: Image is up to date for hwdsl2/litellm-server:latest
```

否則將下載最新版本。刪除並重新建立容器：

```bash
docker rm -f litellm
# 然後使用相同的磁碟區和連接埠重新執行快速開始中的 docker run 命令。
```

您的資料保存在 `litellm-data` 磁碟區中。

## 授權條款

**注：** 預建映像檔中的軟體元件（如 LiteLLM 及其相依套件）遵循各自版權持有者所選擇的相應授權條款。對於任何預建映像檔的使用，映像檔使用者有責任確保其使用符合映像檔中所有軟體的相關授權條款。

版權所有 (C) 2026 Lin Song   
本作品依據 [MIT 授權條款](https://opensource.org/licenses/MIT)授權。

**LiteLLM** 版權所有 (C) 2023 Berri AI，依照 [MIT 授權條款](https://github.com/BerriAI/litellm/blob/main/LICENSE)分發。

本專案為 LiteLLM 的獨立 Docker 部署方案，與 LiteLLM 的開發者 Berri AI 無任何關聯，亦未獲其認可或贊助。