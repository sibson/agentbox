#!/usr/bin/env bash
# Requires Docker: launches containers to verify allowlist enforcement.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_RUN="${REPO_ROOT}/bin/agentbox-codex"

VERBOSE="${VERBOSE:-0}"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

run_agent_silent() {
  if [[ "${VERBOSE}" == "1" ]]; then
    AGENTBOX_VERBOSE=1 "${CODEX_RUN}" -- "$@"
  else
    AGENTBOX_VERBOSE=0 "${CODEX_RUN}" -- "$@" >/dev/null 2>&1
  fi
}

echo "Running network allowlist (docker) tests..."

curl_cmd=(bash -lc "curl --silent --fail --max-time 8 https://example.com >/dev/null")

echo "[1/3] default deny for example.com"
pushd "${tmpdir}" >/dev/null
if run_agent_silent "${curl_cmd[@]}"; then
  echo "example.com should be blocked by default allowlist" >&2
  exit 1
fi
popd >/dev/null

echo "[2/3] allow via allow_file"
mkdir -p "${tmpdir}/.agentbox"
cat >"${tmpdir}/.agentbox/config.toml" <<'EOF'
[network]
mode = "allowlist"
allow_hosts = []
allow_file = "allow-extra.txt"
EOF
cat >"${tmpdir}/.agentbox/allow-extra.txt" <<'EOF'
# permitted hosts
example.com
EOF
pushd "${tmpdir}" >/dev/null
if ! run_agent_silent "${curl_cmd[@]}"; then
  echo "example.com should be reachable when added via allow_file" >&2
  exit 1
fi
popd >/dev/null

echo "[3/3] block overrides allow"
cat >"${tmpdir}/.agentbox/config.toml" <<'EOF'
[network]
mode = "allowlist"
allow_hosts = ["example.com"]
block_hosts = ["example.com"]
EOF
pushd "${tmpdir}" >/dev/null
if run_agent_silent "${curl_cmd[@]}"; then
  echo "example.com should be blocked when listed in block_hosts" >&2
  exit 1
fi
popd >/dev/null

echo "network allowlist (docker) tests passed."
