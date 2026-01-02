#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGENTBOX_RUN="${REPO_ROOT}/bin/agentbox-run"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

config_dir="${tmpdir}/.agentbox"
mkdir -p "${config_dir}"

cat >"${config_dir}/config.toml" <<'EOF'
[network]
mode = "allowlist"
allow_hosts = ["api.github.com", "registry.npmjs.org", "*.rgate.click"]
block_hosts = ["chatgpt.com", "*.blocked.test"]
allow_file = "allow-extra.txt"
EOF

cat >"${config_dir}/allow-extra.txt" <<'EOF'
# extra allowlist entries
downloads.example.com
*.blocked.test
 api.github.com
EOF

pushd "${tmpdir}" >/dev/null
output="$(HOME="${tmpdir}" AGENTBOX_ONLY_PRINT_ALLOWLIST=1 AGENTBOX_VERBOSE=0 "${AGENTBOX_RUN}" codex)"
popd >/dev/null

actual=()
while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  actual+=("${line}")
done <<<"${output}"

expected=(
  "*.rgate.click"
  "api.anthropic.com"
  "api.github.com"
  "api.openai.com"
  "auth.openai.com"
  "chat.openai.com"
  "downloads.example.com"
  "platform.openai.com"
  "registry.npmjs.org"
)

expected_sorted="$(printf '%s\n' "${expected[@]}" | sort)"
actual_sorted="$(printf '%s\n' "${actual[@]}" | sort)"

if [[ "${actual_sorted}" != "${expected_sorted}" ]]; then
  echo "allowlist parsing mismatch"
  echo "expected:"
  while IFS= read -r line; do
    printf '  %s\n' "${line}"
  done <<<"${expected_sorted}"
  echo "got:"
  while IFS= read -r line; do
    printf '  %s\n' "${line}"
  done <<<"${actual_sorted}"
  exit 1
fi

echo "allowlist parsing passed"
