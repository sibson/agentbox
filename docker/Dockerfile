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
        iptables \
        jq \
        netcat-traditional \
        nodejs \
        npm \
        procps \
    && rm -rf /var/lib/apt/lists/*

ARG TOOLKITS=""

RUN useradd \
      --create-home \
      --home-dir "${AGENT_HOME}" \
      --shell /bin/bash \
      "${AGENT_USERNAME}"

RUN mkdir -p "${AGENT_HOME}/.config" && chown -R "${AGENT_USERNAME}:${AGENT_USERNAME}" "${AGENT_HOME}/.config"

RUN npm install -g @openai/codex && npm cache clean --force

WORKDIR /workspace
COPY docker/entrypoint.sh /usr/local/bin/agent-entrypoint
COPY docker/firewall.sh /usr/local/bin/agent-firewall
RUN chmod +x /usr/local/bin/agent-entrypoint /usr/local/bin/agent-firewall

COPY toolkits /opt/agentbox/toolkits

RUN if [ -n "${TOOLKITS}" ]; then \
      set -e; \
      apt-get update; \
      for tk in $(echo "${TOOLKITS}" | tr ',' ' '); do \
        file="/opt/agentbox/toolkits/${tk}.list"; \
        if [ ! -f "${file}" ]; then \
          echo "Unknown toolkit '${tk}'" >&2; \
          exit 1; \
        fi; \
        pkgs="$(grep -vE '^\s*#' "${file}" | tr '\n' ' ' | xargs)"; \
        if [ -n "${pkgs}" ]; then \
          apt-get install -y --no-install-recommends ${pkgs}; \
        fi; \
      done; \
      rm -rf /var/lib/apt/lists/*; \
    fi

RUN runuser -u "${AGENT_USERNAME}" -- bash -lc 'curl -fsSL https://claude.ai/install.sh | bash'

USER ${AGENT_USERNAME}

ENTRYPOINT ["/usr/local/bin/agent-entrypoint"]
