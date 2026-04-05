#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

FROM python:3.12-slim

WORKDIR /opt/src

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

RUN set -x \
    && apt-get update \
    && apt-get install -y --no-install-recommends curl wget \
    && apt-get install -y --no-install-recommends \
         gcc libffi-dev libssl-dev \
    && python3 -m venv /opt/venv \
    && pip install --no-cache-dir "litellm[proxy]" prisma \
    && LITELLM_SCHEMA=$(python3 -c 'import litellm, os; print(os.path.join(os.path.dirname(litellm.__file__), "proxy", "schema.prisma"))') \
    && DATABASE_URL="postgresql://dummy:dummy@localhost/dummy" \
       prisma generate --schema "$LITELLM_SCHEMA" \
    && apt-get purge -y gcc libffi-dev libssl-dev \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && find /opt/venv -name '*.pyi' -delete \
    && find /opt/venv -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true \
    && mkdir -p /etc/litellm

COPY ./run.sh /opt/src/run.sh
COPY ./manage.sh /opt/src/manage.sh
COPY ./LICENSE.md /opt/src/LICENSE.md
RUN chmod 755 /opt/src/run.sh /opt/src/manage.sh \
    && ln -s /opt/src/manage.sh /usr/local/bin/litellm_manage

EXPOSE 4000/tcp
VOLUME ["/etc/litellm"]
CMD ["/opt/src/run.sh"]

ARG BUILD_DATE
ARG VERSION
ARG VCS_REF
ENV IMAGE_VER=$BUILD_DATE

LABEL maintainer="Lin Song <linsongui@gmail.com>" \
    org.opencontainers.image.created="$BUILD_DATE" \
    org.opencontainers.image.version="$VERSION" \
    org.opencontainers.image.revision="$VCS_REF" \
    org.opencontainers.image.authors="Lin Song <linsongui@gmail.com>" \
    org.opencontainers.image.title="LiteLLM AI Gateway on Docker" \
    org.opencontainers.image.description="Docker image to run a LiteLLM AI gateway proxy, providing a unified OpenAI-compatible API for 100+ LLM providers." \
    org.opencontainers.image.url="https://github.com/hwdsl2/docker-litellm" \
    org.opencontainers.image.source="https://github.com/hwdsl2/docker-litellm" \
    org.opencontainers.image.documentation="https://github.com/hwdsl2/docker-litellm"