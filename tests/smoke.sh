#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_RUN="${REPO_ROOT}/bin/agentbox-codex"
CLAUDE_RUN="${REPO_ROOT}/bin/agentbox-claude"

VERBOSE=0

usage() {
  cat <<'USAGE'
Usage: tests/smoke.sh [--verbose]

Runs the Agentbox smoke tests (identity, workspace access, CLI availability).

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

echo "[1/5] verifying agent identity"
output="$(run_agent_capture "${CODEX_RUN}" -- whoami)"
if [[ "${output}" != "agent" ]]; then
  echo "expected user 'agent', got '${output}'" >&2
  exit 1
fi

echo "[2/5] verifying workspace access"
test_file="${tmpdir}/sandbox.txt"
echo "host-data" > "${test_file}"
pushd "${tmpdir}" >/dev/null
run_agent_silent "${CODEX_RUN}" -- bash -c "echo container >> sandbox.txt"
popd >/dev/null
if ! grep -q "container" "${test_file}"; then
  echo "container write did not propagate back to host" >&2
  exit 1
fi

echo "[3/5] skipping network isolation (full network allowed)"

echo "[4/5] verifying agent CLIs"
if ! run_agent_silent "${CODEX_RUN}" -- bash -lc "command -v codex >/dev/null"; then
  echo "codex CLI not functioning" >&2
  exit 1
fi
if ! run_agent_silent "${CLAUDE_RUN}" -- bash -lc "command -v claude >/dev/null"; then
  echo "claude CLI not functioning" >&2
  exit 1
fi

echo "[5/5] verifying default agent launch"
if ! AGENTBOX_TTY=0 AGENTBOX_VERBOSE=0 "${CODEX_RUN}" >/dev/null 2>&1; then
  echo "default agent launch failed without explicit command" >&2
  exit 1
fi

if [[ "${VERBOSE}" == "1" ]]; then
  echo "All smoke tests passed."
else
  echo "Smoke tests passed."
fi
