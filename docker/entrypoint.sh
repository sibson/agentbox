#!/usr/bin/env bash
set -euo pipefail

DEFAULT_COMMAND="${AGENTBOX_DEFAULT_COMMAND:-}"
DEFAULT_ARGS="${AGENTBOX_DEFAULT_ARGS:-}"

DEFAULT_ARGS_ARRAY=()
if [[ -n "${DEFAULT_ARGS}" ]]; then
  read -r -a DEFAULT_ARGS_ARRAY <<<"${DEFAULT_ARGS}"
fi

if [[ $# -eq 0 ]]; then
  if [[ -n "${DEFAULT_COMMAND}" ]] && command -v "${DEFAULT_COMMAND}" >/dev/null 2>&1; then
    if [[ ${#DEFAULT_ARGS_ARRAY[@]} -gt 0 ]]; then
      exec "${DEFAULT_COMMAND}" "${DEFAULT_ARGS_ARRAY[@]}"
    else
      exec "${DEFAULT_COMMAND}"
    fi
  else
    exec /bin/bash
  fi
else
  exec "$@"
fi
