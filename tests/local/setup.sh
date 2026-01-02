#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

expected="$(cat <<'EOF'
# Agentbox configuration

[toolkits]
selected = ["python", "c_cpp"]
# Example: selected = ["python", "c_cpp"]

[agent]
# default = "last_used" # or "codex"/"claude"; falls back to explicit agent args/env

[network]
# Defaults allow OpenAI/Anthropic API hosts; uncomment to customize.
# allow_hosts = ["api.github.com", "registry.npmjs.org", "*.example.com"]
# block_hosts = ["chatgpt.com"] # optional removals from defaults; glob patterns allowed
# allow_file = "extra-hosts.txt" # optional, relative to this file
EOF
)"

actual="$(cat "${CONFIG_PATH}")"
if [[ "${actual}" != "${expected}" ]]; then
  echo "unexpected config content in .agentbox/config.toml" >&2
  echo "expected:" >&2
  printf '%s\n' "${expected}" >&2
  echo "got:" >&2
  printf '%s\n' "${actual}" >&2
  exit 1
fi

echo "setup test passed"
