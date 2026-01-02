#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGENTBOX_RUN="${REPO_ROOT}/bin/agentbox-run"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

HOME="${tmpdir}"
export HOME

config_dir="${tmpdir}/.agentbox"
mkdir -p "${config_dir}"
config_path="${config_dir}/config.toml"
last_agent_file="${config_dir}/last_agent"

write_config() {
  local default_agent="$1"
  cat >"${config_path}" <<EOF
[agent]
default = "${default_agent}"

[network]
allow_hosts = []
EOF
}

echo "Running default agent tests..."

write_config "last_used"

echo "[1/3] fails without last_agent when default=last_used"
if AGENTBOX_ONLY_PRINT_ALLOWLIST=1 AGENTBOX_VERBOSE=0 AGENTBOX_LAST_AGENT_FILE="${last_agent_file}" "${AGENTBOX_RUN}" >/dev/null 2>&1; then
  echo "expected default agent lookup to fail without last_agent file" >&2
  exit 1
fi

echo "[2/3] falls back to last_agent when present"
echo "claude" > "${last_agent_file}"
if ! AGENTBOX_ONLY_PRINT_ALLOWLIST=1 AGENTBOX_VERBOSE=0 AGENTBOX_LAST_AGENT_FILE="${last_agent_file}" "${AGENTBOX_RUN}" >/dev/null; then
  echo "expected default agent to resolve from last_agent file" >&2
  exit 1
fi
if [[ "$(tr -d '[:space:]' < "${last_agent_file}")" != "claude" ]]; then
  echo "last_agent file should remain unchanged by allowlist print path" >&2
  exit 1
fi

echo "[3/3] uses explicit default agent when provided"
write_config "codex"
rm -f "${last_agent_file}"
if ! AGENTBOX_ONLY_PRINT_ALLOWLIST=1 AGENTBOX_VERBOSE=0 AGENTBOX_LAST_AGENT_FILE="${last_agent_file}" "${AGENTBOX_RUN}" >/dev/null; then
  echo "expected explicit default agent to be used" >&2
  exit 1
fi

echo "default agent tests passed"
