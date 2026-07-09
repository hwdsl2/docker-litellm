[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# LiteLLM AI-шлюз на Docker

[![Build Status](https://github.com/hwdsl2/docker-litellm/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-litellm/actions/workflows/main.yml) &nbsp;[![Docker Pulls](https://raw.githubusercontent.com/hwdsl2/badges/main/img/docker-pulls-litellm-server.svg)](https://hub.docker.com/r/hwdsl2/litellm-server) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

Часть [Self-Hosted AI Stack](https://github.com/hwdsl2/self-hosted-ai-stack/blob/main/README-ru.md) — разверните полный самостоятельно размещённый AI-стек одной командой.

Docker-образ для запуска прокси-шлюза [LiteLLM](https://github.com/BerriAI/litellm). Обеспечивает единую точку доступа через OpenAI-совместимый API для более чем 100 провайдеров больших языковых моделей (LLM). Основан на Debian (python:3.12-slim). Прост в использовании, приватен и самостоятельно размещаем.

**Возможности:**

- **Безопасность по умолчанию** — автоматически генерирует мастер-ключ API при первом запуске; все API-запросы требуют этот ключ
- Автоматически добавляет модели для провайдеров, ключи которых заданы в env-файле
- Управление моделями через вспомогательный скрипт (`litellm_manage`)
- `docker-compose.yml` включает базу данных PostgreSQL для панели администратора, управления виртуальными ключами и отслеживания расходов
- OpenAI-совместимый прокси API — достаточно изменить одну строку, чтобы направить рабочие процессы OpenAI SDK и приложений на этот прокси
- Поддерживает OpenAI, Anthropic, Groq, Gemini, Ollama и [100+ других провайдеров](https://docs.litellm.ai/docs/providers)
- Поддерживаемые эндпоинты и поля зависят от LiteLLM, выбранного провайдера и возможностей модели
- Автоматически собирается и публикуется через [GitHub Actions](https://github.com/hwdsl2/docker-litellm/actions/workflows/main.yml)
- Постоянное хранение данных через Docker-том
- Мультиархитектурная поддержка: `linux/amd64`, `linux/arm64`

**Также доступно:**

- AI-стек: [Self-Hosted AI Stack](https://github.com/hwdsl2/self-hosted-ai-stack/blob/main/README-ru.md)
- Связанные AI-сервисы: [Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-ru.md), [Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-ru.md), [Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-ru.md), [Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-ru.md), [Docling](https://github.com/hwdsl2/docker-docling/blob/main/README-ru.md), [MCP Gateway](https://github.com/hwdsl2/docker-mcp-gateway/blob/main/README-ru.md)

## Сообщество

- 📬 [Подписаться на обновления проектов](https://selfhostedstack.beehiiv.com/subscribe?utm_campaign=ai-ru) (1–2 письма в месяц) — получить бесплатные руководства по развёртыванию AI и VPN (PDF, на английском)
- 💬 Присоединяйтесь к сообществу [r/selfhostedstack](https://www.reddit.com/r/selfhostedstack/) для обсуждений и демонстрации проектов
- ⭐ Поставьте звезду репозиторию, если он оказался вам полезен — это поможет другим пользователям его найти.

<details>
<summary>Самостоятельно размещаемые VPN и сетевые проекты</summary>

- [Setup IPsec VPN](https://github.com/hwdsl2/setup-ipsec-vpn/blob/master/README-ru.md)
- [IPsec VPN на Docker](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-ru.md)
- [WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-ru.md)
- [OpenVPN](https://github.com/hwdsl2/docker-openvpn/blob/main/README-ru.md)
- [Headscale](https://github.com/hwdsl2/docker-headscale/blob/main/README-ru.md)

</details>

## Быстрый старт

**Шаг 1.** Запустите прокси LiteLLM:

```bash
docker run \
    --name litellm \
    --restart=always \
    -v litellm-data:/etc/litellm \
    -p 4000:4000/tcp \
    -d hwdsl2/litellm-server
```

При первом запуске сервер автоматически генерирует мастер-ключ API и создаёт конфигурацию. Мастер-ключ выводится в логах контейнера.

**Примечание:** Для развёртываний, доступных из интернета, **настоятельно рекомендуется** добавить HTTPS с помощью [обратного прокси](#использование-обратного-прокси). В этом случае также замените `-p 4000:4000/tcp` на `-p 127.0.0.1:4000:4000/tcp` в команде `docker run` выше, чтобы исключить прямой доступ к незашифрованному порту извне.

**Шаг 2.** Просмотрите логи контейнера, чтобы получить мастер-ключ:

```bash
docker logs litellm
```

Мастер-ключ отображается в рамке с заголовком **LiteLLM proxy master key**. Скопируйте этот ключ — он используется для аутентификации всех API-запросов.

**Примечание:** Мастер-ключ выводится только при первоначальной настройке. Чтобы отобразить его в любой момент, выполните:

```bash
docker exec litellm litellm_manage --showkey
```

**Шаг 3.** Проверьте работу прокси с помощью OpenAI-совместимого запроса:

```bash
# Получить список доступных моделей
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer <ваш-мастер-ключ>"

# Отправить запрос на генерацию текста (после добавления модели — см. ниже)
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer <ваш-мастер-ключ>" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o", "messages": [{"role": "user", "content": "Привет!"}]}'
```

**Примечание:** Команда для отправки запроса на генерацию текста требует, чтобы сначала была настроена хотя бы одна модель. См. раздел [Управление моделями](#управление-моделями).

## Требования

- Сервер Linux (локальный или облачный) с установленным Docker
- Хотя бы один API-ключ провайдера LLM (OpenAI, Anthropic, Groq и др.) **или** локально запущенный экземпляр [Ollama](https://github.com/hwdsl2/docker-ollama)
- Открытый TCP-порт 4000 (или настроенный вами порт)

Запуск прокси возможен без ключей провайдеров LLM — сервер успешно стартует с пустым списком моделей. Модели можно добавить в любой момент с помощью `litellm_manage`.

Для развёртываний, доступных из интернета, см. раздел [Использование обратного прокси](#использование-обратного-прокси) для добавления HTTPS.

## Загрузка

Получите надёжную сборку из [реестра Docker Hub](https://hub.docker.com/r/hwdsl2/litellm-server/):

```bash
docker pull hwdsl2/litellm-server
```

Также можно загрузить из [Quay.io](https://quay.io/repository/hwdsl2/litellm-server):

```bash
docker pull quay.io/hwdsl2/litellm-server
docker image tag quay.io/hwdsl2/litellm-server hwdsl2/litellm-server
```

Поддерживаемые платформы: `linux/amd64` и `linux/arm64`.

## Переменные окружения

Все переменные необязательны. Если `LITELLM_MASTER_KEY` не задан, мастер-ключ API автоматически генерируется при первом запуске.

Данный Docker-образ использует следующие переменные, которые можно объявить в файле `env` (см. [пример](litellm.env.example)):

| Переменная | Описание | По умолчанию |
|---|---|---|
| `LITELLM_MASTER_KEY` | Мастер-ключ API для прокси | Генерируется автоматически |
| `LITELLM_PORT` | TCP-порт для прокси (1–65535) | `4000` |
| `LITELLM_HOST` | Имя хоста или IP, отображаемое при запуске и в выводе `--showkey` | Определяется автоматически |
| `LITELLM_LOG_LEVEL` | Уровень логирования: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` | `INFO` |
| `LITELLM_OPENAI_API_KEY` | API-ключ OpenAI — автодобавляет `gpt-4o`, `gpt-4o-mini` | *(не задано)* |
| `LITELLM_ANTHROPIC_API_KEY` | API-ключ Anthropic — автодобавляет `claude-3-6-sonnet` (latest) | *(не задано)* |
| `LITELLM_GROQ_API_KEY` | API-ключ Groq — автодобавляет `llama-3.3-70b` | *(не задано)* |
| `LITELLM_GEMINI_API_KEY` | API-ключ Google Gemini — автодобавляет `gemini-2.0-flash` | *(не задано)* |
| `LITELLM_OLLAMA_BASE_URL` | Базовый URL Ollama — гарантирует наличие `ollama/llama3.2:3b` и `ollama-chat/llama3.2:3b` | *(не задано)* |
| `LITELLM_OLLAMA_API_KEY` | API-ключ Ollama (автоматически считывается из общего тома в [self-hosted-ai-stack](https://github.com/hwdsl2/self-hosted-ai-stack/blob/main/README-ru.md)) | *(не задано)* |
| `LITELLM_DATABASE_URL` | URL PostgreSQL — включает управление виртуальными ключами | *(не задано)* |
| `LITELLM_POSTGRES_PASSWORD_FILE` | Файл с паролем PostgreSQL для Compose; используется только если `LITELLM_DATABASE_URL` не задан | *(не задано)* |
| `LITELLM_MCP_URL` | URL конечной точки MCP Gateway — автоподключение к MCP Gateway при каждом запуске | *(не задано)* |
| `LITELLM_MCP_API_KEY` | Bearer-токен для MCP Gateway (обязателен при установке `LITELLM_MCP_URL`) | *(не задано)* |
| `LITELLM_DISABLE_USAGE_COUNTS` | Установите `1`, чтобы отключить анонимные агрегированные счётчики использования. | *(не задано)* |

**Примечание:** В файле `env` можно заключать значения в одинарные кавычки, например `VAR='значение'`. Не добавляйте пробелы вокруг `=`. Если вы изменили `LITELLM_PORT`, обновите флаг `-p` в команде `docker run` соответствующим образом.

Пример с использованием файла `env`:

```bash
cp litellm.env.example litellm.env
# Отредактируйте litellm.env и задайте ваши API-ключи, затем:
docker run \
    --name litellm \
    --restart=always \
    -v litellm-data:/etc/litellm \
    -v ./litellm.env:/litellm.env:ro \
    -p 4000:4000/tcp \
    -d hwdsl2/litellm-server
```

Файл env монтируется в контейнер через bind mount, поэтому изменения применяются при каждом перезапуске контейнера без его пересоздания.

## Управление моделями

Используйте `docker exec` для управления моделями через вспомогательный скрипт `litellm_manage`. Модели хранятся в файле `config.yaml` внутри Docker-тома и сохраняются после перезапуска контейнера.

**Примечание:** `--addmodel` и `--removemodel` записывают изменения в `config.yaml` и автоматически перезапускают прокси для их применения.

Если задан `LITELLM_OLLAMA_BASE_URL`, контейнер поддерживает в `config.yaml` два стандартных псевдонима Ollama: `ollama/llama3.2:3b` для обратной совместимости и `ollama-chat/llama3.2:3b` для нативного chat-поведения Ollama. Для потоковых вызовов инструментов используйте псевдоним `ollama-chat/...`.

**Список настроенных моделей:**

```bash
docker exec litellm litellm_manage --listmodels
```

**Добавление модели с API-ключом:**

```bash
# OpenAI
docker exec litellm litellm_manage --addmodel openai/gpt-4o --key sk-...

# Anthropic
docker exec litellm litellm_manage --addmodel anthropic/claude-3-6-sonnet-latest --key sk-ant-...

# Groq
docker exec litellm litellm_manage --addmodel groq/llama-3.3-70b-versatile --key gsk_...

# Добавить с пользовательским отображаемым именем (псевдоним)
docker exec litellm litellm_manage --addmodel openai/gpt-4o --key sk-... --alias my-gpt4

# Отметить модель как поддерживающую function calling
docker exec litellm litellm_manage \
  --addmodel ollama_chat/llama3.2:3b \
  --alias ollama-chat/llama3.2:3b \
  --base-url http://host.docker.internal:11434 \
  --supports-function-calling
```

**Добавление локальной модели Ollama:**

```bash
# Подключиться к Ollama, запущенному на хосте Docker
docker exec litellm litellm_manage \
  --addmodel ollama/llama3.2:3b \
  --base-url http://host.docker.internal:11434
```

Для моделей Ollama, которым требуется нативное chat-поведение или потоковые вызовы инструментов, используйте provider model `ollama_chat/...` с пользовательским псевдонимом, например `ollama-chat/llama3.2:3b`.

**Удаление модели** (используйте поле `id` из вывода `--listmodels`):

```bash
docker exec litellm litellm_manage --removemodel <model_id>
```

**Показать мастер-ключ** (если нужно его найти):

```bash
# Полный вывод с информацией об эндпоинте
docker exec litellm litellm_manage --showkey

# Только ключ (для скриптов — без IP и информации об эндпоинте)
docker exec litellm litellm_manage --getkey
```

## Интеграция с MCP Gateway

Укажите `LITELLM_MCP_URL` (и при необходимости `LITELLM_MCP_API_KEY`) в файле `litellm.env`, чтобы автоматически подключить LiteLLM к MCP Gateway — AI-клиенты смогут вызывать MCP-инструменты напрямую через прокси LiteLLM.

При наличии `LITELLM_MCP_URL` блок `mcp_servers:` автоматически добавляется в `config.yaml` при каждом запуске контейнера — ручное редактирование YAML не требуется.

**Подключение к MCP Gateway:**

```bash
# В файле litellm.env:
LITELLM_MCP_URL=http://mcp:3000/mcp
LITELLM_MCP_API_KEY=mcp-xxxx...   # получить командой: docker exec mcp mcp_manage --showkey
```

После задания этих значений перезапустите контейнер:

```bash
docker compose restart litellm
# или: docker restart litellm
```

**Управление MCP-серверами через `litellm_manage`:**

```bash
# Список настроенных MCP-серверов
docker exec litellm litellm_manage --listmcp

# Добавить MCP-сервер вручную
docker exec litellm litellm_manage --addmcp my-gateway http://mcp:3000/mcp --key mcp-xxxx

# Удалить MCP-сервер
docker exec litellm litellm_manage --removemcp my-gateway
```

**Примечание:** `--addmcp` и `--removemcp` записывают изменения в `config.yaml` и автоматически перезапускают прокси. MCP-серверы, добавленные через `LITELLM_MCP_URL`, имеют имя `docker_mcp_gateway` в конфигурации и управляются командой `--removemcp docker_mcp_gateway`.

## Управление виртуальными ключами

Виртуальные ключи — это ограниченные API-ключи, которые можно выдавать пользователям или приложениям. Каждый ключ может опционально ограничивать доступные модели, устанавливать максимальный бюджет расходов и срок действия. Виртуальные ключи требуют базы данных PostgreSQL, которая включена в стандартный `docker-compose.yml`.

**Создать виртуальный ключ:**

```bash
# Базовый ключ (без ограничений)
docker exec litellm litellm_manage --createkey

# Ключ с псевдонимом, ограничением моделей, бюджетом и сроком действия
docker exec litellm litellm_manage --createkey \
  --alias dev-key \
  --models gpt-4o,claude-3-6-sonnet \
  --budget 20.0 \
  --expires 30d
```

**Список всех виртуальных ключей:**

```bash
docker exec litellm litellm_manage --listkeys
```

**Удалить виртуальный ключ:**

```bash
docker exec litellm litellm_manage --deletekey sk-...
```

## Использование с OpenAI SDK

Направьте приложения, использующие OpenAI SDK, на ваш прокси, задав две переменные окружения:

```bash
export OPENAI_API_KEY="<ваш-мастер-ключ>"
export OPENAI_BASE_URL="http://<IP-сервера>:4000"
```

Пример на Python:

```python
from openai import OpenAI

client = OpenAI(
    api_key="<ваш-мастер-ключ>",
    base_url="http://<IP-сервера>:4000",
)

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Привет!"}],
)
print(response.choices[0].message.content)
```

## Постоянное хранение данных

Все данные прокси хранятся в Docker-томе (в контейнере — папка `/etc/litellm`):

```
/etc/litellm/
├── config.yaml       # Конфигурация прокси и список моделей (создаётся один раз, сохраняется при перезапуске)
├── .master_key       # Мастер-ключ API (автосгенерированный или синхронизированный из LITELLM_MASTER_KEY)
├── .initialized      # Маркер первого запуска
└── .db_configured    # Присутствует, когда задан LITELLM_DATABASE_URL (используется litellm_manage)
```

Создавайте резервные копии Docker-тома для сохранения мастер-ключа и настроенных моделей.

## Использование docker-compose

```bash
cp litellm.env.example litellm.env
# Отредактируйте litellm.env и задайте ваши API-ключи, затем:
docker compose up -d
docker logs litellm
```

Новые установки Compose автоматически генерируют случайный пароль PostgreSQL и сохраняют его в томе `litellm-secrets`. Существующие установки с паролем по умолчанию продолжают использовать старый пароль базы данных `litellm` для совместимости. Если вы ранее настроили собственный пароль базы данных, задайте `LITELLM_POSTGRES_PASSWORD` в окружении shell с этим паролем перед запуском `docker compose up -d` или сохраните явное переопределение `LITELLM_DATABASE_URL` в `litellm.env`.

При обновлении существующего checkout сначала выполните `docker compose pull`, а затем `docker compose up -d`, чтобы образ LiteLLM поддерживал `LITELLM_POSTGRES_PASSWORD_FILE`.

Пример `docker-compose.yml` (уже включён):

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

**Примечание:** Для развёртываний, доступных из интернета, **настоятельно рекомендуется** добавить HTTPS с помощью [обратного прокси](#использование-обратного-прокси). В этом случае также замените `"4000:4000/tcp"` на `"127.0.0.1:4000:4000/tcp"` в файле `docker-compose.yml`, чтобы исключить прямой доступ к незашифрованному порту извне.

## Использование обратного прокси

Для развёртывания с выходом в интернет разместите обратный прокси перед LiteLLM для обработки HTTPS-терминации. Сервер работает без HTTPS в локальной или доверенной сети, но HTTPS рекомендуется при открытом доступе к API-эндпоинту из интернета.

Используйте один из следующих адресов для доступа к контейнеру LiteLLM из обратного прокси:

- **`litellm:4000`** — если ваш обратный прокси работает как контейнер в **той же Docker-сети**, что и LiteLLM (например, определён в том же `docker-compose.yml`).
- **`127.0.0.1:4000`** — если ваш обратный прокси работает **на хосте** и порт `4000` опубликован (по умолчанию `docker-compose.yml` публикует его).

**Пример с [Caddy](https://caddyserver.com/docs/) ([Docker-образ](https://hub.docker.com/_/caddy))** (автоматический TLS через Let's Encrypt, обратный прокси в той же Docker-сети):

`Caddyfile`:
```
litellm.example.com {
  reverse_proxy litellm:4000
}
```

**Пример с nginx** (обратный прокси на хосте):

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

После настройки обратного прокси задайте `LITELLM_HOST=litellm.example.com` в файле `env`, чтобы правильный URL конечной точки отображался в логах запуска и в выводе `litellm_manage --showkey`.

Автоматически сгенерированный мастер-ключ API обязателен для всех API-запросов. Храните его в безопасности, когда сервер доступен из публичного интернета.

## Обновление Docker-образа

Для обновления Docker-образа и контейнера сначала [загрузите](#загрузка) последнюю версию:

```bash
docker pull hwdsl2/litellm-server
```

Если образ уже актуален, вы увидите:

```
Status: Image is up to date for hwdsl2/litellm-server:latest
```

В противном случае будет загружена последняя версия. Удалите и пересоздайте контейнер:

```bash
docker rm -f litellm
# Затем выполните команду docker run из раздела «Быстрый старт» с теми же томом и портом.
```

Ваши данные сохраняются в томе `litellm-data`.

## Использование с другими AI-сервисами

LiteLLM можно использовать как AI-шлюз в более широком self-hosted AI-стеке.

Готовые полные и облегчённые стеки Docker Compose, примеры ручного запуска через `docker run`, а также примеры голосовых, RAG- и MCP-конвейеров с Kokoro, Embeddings, LiteLLM, Ollama, Docling и MCP Gateway см. в [Self-Hosted AI Stack](https://github.com/hwdsl2/self-hosted-ai-stack/blob/main/README-ru.md).

## Счётчики использования

Этот образ использует публичные счётчики скачиваний GitHub Release assets для анонимной агрегированной статистики использования. Эти числа приблизительны и не являются количеством уникальных пользователей или активных установок. Образ не отправляет telemetry payload и не использует частный сборщик. Он выполняет только best-effort запрос после успешного запуска прокси с подключённым томом `/etc/litellm`, а также при первом запуске другой сборки образа для этой постоянной установки. Чтобы отключить это, задайте `LITELLM_DISABLE_USAGE_COUNTS=1`.

## Технические подробности

- Базовый образ: `python:3.12-slim` (Debian)
- Среда выполнения: Python 3 (виртуальное окружение в `/opt/venv`)
- LiteLLM: последняя версия `litellm[proxy]` из PyPI
- Директория данных: `/etc/litellm` (Docker-том)
- Хранение моделей: `config.yaml` внутри тома — создаётся при первом запуске, сохраняется при перезапусках
- REST API управления прокси: работает на том же порту, что и прокси
- Встроенный UI: доступен по адресу `http://<сервер>:<порт>/ui` — войдите с именем пользователя `admin` и вашим мастер-ключом в качестве пароля

## Лицензия

**Примечание:** Программные компоненты внутри предсобранного образа (такие как LiteLLM и его зависимости) распространяются под соответствующими лицензиями, выбранными их правообладателями. При использовании любого предсобранного образа пользователь несёт ответственность за соблюдение всех соответствующих лицензий на программное обеспечение, содержащееся в образе.

Авторские права (C) 2026 Lin Song   
Данная работа распространяется на условиях [лицензии MIT](https://opensource.org/licenses/MIT).

**LiteLLM** — авторские права (C) 2023 Berri AI, распространяется на условиях [лицензии MIT](https://github.com/BerriAI/litellm/blob/main/LICENSE).

Этот проект представляет собой независимую Docker-конфигурацию для LiteLLM и не связан с компанией Berri AI, разработчиком LiteLLM, а также не одобрен и не спонсируется ею。
