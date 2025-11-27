#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${REPO_ROOT}/bin/agentbox-setup"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

pushd "${tmpdir}" >/dev/null

# Run setup non-interactively with a known selection
printf "python c_cpp\n" | "${SCRIPT}" >/dev/null

CONFIG_PATH="${tmpdir}/.agentbox/config.toml"
if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo ".agentbox/config.toml was not created" >&2
  exit 1
fi

expected='selected = ["python", "c_cpp"]'
if ! grep -F -q "${expected}" "${CONFIG_PATH}"; then
  echo "unexpected toolkit selection in .agentbox" >&2
  cat "${CONFIG_PATH}"
  exit 1
fi

echo "setup test passed"
