#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_RUN="${REPO_ROOT}/bin/agentbox-codex"
CLAUDE_RUN="${REPO_ROOT}/bin/agentbox-claude"

VERBOSE=0

usage() {
  cat <<'USAGE'
Usage: tests/smoke.sh [--verbose]

Runs the Agentbox smoke tests (identity, workspace access, CLI availability, codex prompt).

Options:
  -v, --verbose   Show per-step status and container logs.
  -h, --help      Display this message.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

info() {
  if [[ "${VERBOSE}" == "1" ]]; then
    echo "$@"
  fi
}

run_agent_capture() {
  if [[ "${VERBOSE}" == "1" ]]; then
    AGENTBOX_VERBOSE=1 "$@"
  else
    AGENTBOX_VERBOSE=0 "$@" 2>/dev/null
  fi
}

run_agent_silent() {
  if [[ "${VERBOSE}" == "1" ]]; then
    AGENTBOX_VERBOSE=1 "$@"
  else
    AGENTBOX_VERBOSE=0 "$@" >/dev/null 2>&1
  fi
}

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

if [[ "${VERBOSE}" == "1" ]]; then
  echo "Running smoke tests (verbose)..."
else
  echo "Running smoke tests..."
fi

echo "[1/6] verifying agent identity"
output="$(run_agent_capture "${CODEX_RUN}" -- whoami)"
if [[ "${output}" != "agent" ]]; then
  echo "expected user 'agent', got '${output}'" >&2
  exit 1
fi

echo "[2/6] verifying workspace access"
test_file="${tmpdir}/sandbox.txt"
echo "host-data" > "${test_file}"
pushd "${tmpdir}" >/dev/null
run_agent_silent "${CODEX_RUN}" -- bash -c "echo container >> sandbox.txt"
popd >/dev/null
if ! grep -q "container" "${test_file}"; then
  echo "container write did not propagate back to host" >&2
  exit 1
fi

echo "[3/6] verifying network allowlist and override"
if run_agent_silent "${CODEX_RUN}" -- bash -lc "curl --silent --fail --max-time 5 https://example.com >/dev/null"; then
  echo "example.com should be blocked by the default allowlist" >&2
  exit 1
fi
if ! run_agent_silent "${CODEX_RUN}" --full-network -- bash -lc "curl --silent --fail --max-time 5 https://example.com >/dev/null"; then
  echo "--full-network did not permit outbound access" >&2
  exit 1
fi

echo "[4/6] verifying agent CLIs"
if ! run_agent_silent "${CODEX_RUN}" -- bash -lc "command -v codex >/dev/null"; then
  echo "codex CLI not functioning" >&2
  exit 1
fi
if ! run_agent_silent "${CLAUDE_RUN}" -- bash -lc "command -v claude >/dev/null"; then
  echo "claude CLI not functioning" >&2
  exit 1
fi

echo "[5/6] verifying codex prompt execution"
codex_prompt_output="$(run_agent_capture "${CODEX_RUN}" --prompt "ping" || true)"
if [[ -z "${codex_prompt_output// }" ]]; then
  echo "codex prompt did not return output" >&2
  exit 1
fi

echo "[6/6] verifying default agent launch"
if ! AGENTBOX_TTY=0 AGENTBOX_VERBOSE=0 "${CODEX_RUN}" >/dev/null 2>&1; then
  echo "default agent launch failed without explicit command" >&2
  exit 1
fi

if [[ "${VERBOSE}" == "1" ]]; then
  echo "All smoke tests passed."
else
  echo "Smoke tests passed."
fi
