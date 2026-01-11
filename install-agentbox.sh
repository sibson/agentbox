#!/usr/bin/env bash
set -euo pipefail

# Defaults
INSTALL_ROOT="${AGENTBOX_ROOT:-${HOME}/.agentbox}"
BIN_DIR="${AGENTBOX_BIN_DIR:-${INSTALL_ROOT}/bin}"
LOCAL_BIN="${HOME}/.local/bin"
BRANCH="${AGENTBOX_BRANCH:-main}"
TARBALL="${AGENTBOX_TARBALL:-}"
DEV_MODE="${AGENTBOX_DEV:-0}"
YES="${AGENTBOX_YES:-0}"

REPO_URL="https://github.com/sibson/agentbox"

usage() {
  cat <<'USAGE'
Usage: install-agentbox.sh [--bin-dir <path>] [--tarball <url-or-path>] [--branch <name>] [--dev] [--yes]

Options:
  --bin-dir <path>   Where to place shims (default: ~/.agentbox/bin)
  --tarball <url|path>  Install from given tarball (overrides branch download)
  --branch <name>    Branch to download when using default tarball (default: main)
  --dev              Use current directory as source (no download)
  --yes              Non-interactive; overwrite existing shims
  -h, --help         Show this help
USAGE
}

fatal() { echo "install-agentbox: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bin-dir)
      [[ $# -ge 2 ]] || fatal "--bin-dir requires a value"
      BIN_DIR="$2"; shift 2;;
    --tarball)
      [[ $# -ge 2 ]] || fatal "--tarball requires a value"
      TARBALL="$2"; shift 2;;
    --branch)
      [[ $# -ge 2 ]] || fatal "--branch requires a value"
      BRANCH="$2"; shift 2;;
    --dev)
      DEV_MODE=1; shift;;
    --yes)
      YES=1; shift;;
    -h|--help)
      usage; exit 0;;
    *)
      fatal "Unknown option '$1'"
      ;;
  esac
done

check_prereq() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fatal "missing required command: $1"
  fi
}

check_prereq docker
check_prereq python3
if ! docker info >/dev/null 2>&1; then
  fatal "docker daemon not available"
fi

mkdir -p "${INSTALL_ROOT}"
mkdir -p "${BIN_DIR}"
mkdir -p "${INSTALL_ROOT}/toolkits"

SRC_DIR="${INSTALL_ROOT}/src"

if [[ "${DEV_MODE}" -eq 1 ]]; then
  SRC_DIR="$(pwd)"
else
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' EXIT

  archive="${tmpdir}/agentbox.tar.gz"
  if [[ -n "${TARBALL}" ]]; then
    if [[ "${TARBALL}" == http*://* ]]; then
      curl -fsSL "${TARBALL}" -o "${archive}"
    else
      cp "${TARBALL}" "${archive}"
    fi
  else
    curl -fsSL "${REPO_URL}/archive/refs/heads/${BRANCH}.tar.gz" -o "${archive}"
  fi

  mkdir -p "${tmpdir}/extract"
  tar -xzf "${archive}" -C "${tmpdir}/extract"
  extracted_dir="$(find "${tmpdir}/extract" -maxdepth 1 -type d -name 'agentbox-*' | head -n1)"
  [[ -n "${extracted_dir}" ]] || fatal "failed to extract archive"

  rm -rf "${INSTALL_ROOT}/src"
  mv "${extracted_dir}" "${INSTALL_ROOT}/src"
  SRC_DIR="${INSTALL_ROOT}/src"
fi

# Create shims (symlinks) pointing to scripts under src/bin
make_link() {
  local target="$1"
  local link_path="$2"
  if [[ -e "${link_path}" || -L "${link_path}" ]]; then
    if [[ "${YES}" -ne 1 ]]; then
      echo "Overwriting existing ${link_path}" >&2
    fi
    rm -f "${link_path}"
  fi
  ln -s "${target}" "${link_path}"
}

for shim in agentbox-codex agentbox-claude agentbox-run agentbox-setup agentbox-update; do
  make_link "${SRC_DIR}/bin/${shim}" "${BIN_DIR}/${shim}"
done

LINKED_LOCAL_BIN=0
if [[ -d "${LOCAL_BIN}" ]] && [[ ":$PATH:" == *":${LOCAL_BIN}:"* ]]; then
  mkdir -p "${LOCAL_BIN}"
  for shim in agentbox-codex agentbox-claude agentbox-run agentbox-setup agentbox-update; do
    make_link "${SRC_DIR}/bin/${shim}" "${LOCAL_BIN}/${shim}"
  done
  LINKED_LOCAL_BIN=1
fi

on_path() {
  case ":$PATH:" in
    *:"$1":*) return 0;;
    *) return 1;;
  esac
}

if on_path "${BIN_DIR}"; then
  PATH_MSG="Shims available on PATH via ${BIN_DIR}"
elif [[ ${LINKED_LOCAL_BIN} -eq 1 ]]; then
  PATH_MSG="Shims linked into ${LOCAL_BIN} (already on PATH)"
else
  PATH_MSG="Add ${BIN_DIR} to your PATH (e.g., export PATH=\"${BIN_DIR}:\$PATH\" in your shell rc)"
fi

cat <<EOF
Agentbox installed.
  Source: ${SRC_DIR}
  Shims:  ${BIN_DIR}
  Toolkits (user): ${INSTALL_ROOT}/toolkits
  ${PATH_MSG}

Next steps:
- Run bin/agentbox-setup to configure toolkits/allowlist if needed.
- Launch: agentbox-codex or agentbox-claude
EOF
