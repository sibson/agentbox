ARG BASE_IMAGE=debian:bookworm-slim

FROM ${BASE_IMAGE}

ARG AGENT_USERNAME=agent
ARG AGENT_HOME=/home/${AGENT_USERNAME}

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="${AGENT_HOME}/.local/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        coreutils \
        curl \
        git \
        iproute2 \
        iputils-ping \
        jq \
        netcat-traditional \
        nodejs \
        npm \
        procps \
    && rm -rf /var/lib/apt/lists/*

RUN useradd \
      --create-home \
      --home-dir "${AGENT_HOME}" \
      --shell /bin/bash \
      "${AGENT_USERNAME}"

RUN mkdir -p "${AGENT_HOME}/.config" && chown -R "${AGENT_USERNAME}:${AGENT_USERNAME}" "${AGENT_HOME}/.config"

RUN npm install -g @openai/codex && npm cache clean --force

WORKDIR /workspace
COPY docker/entrypoint.sh /usr/local/bin/agent-entrypoint
RUN chmod +x /usr/local/bin/agent-entrypoint

RUN runuser -u "${AGENT_USERNAME}" -- bash -lc 'curl -fsSL https://claude.ai/install.sh | bash'

USER ${AGENT_USERNAME}

ENTRYPOINT ["/usr/local/bin/agent-entrypoint"]
