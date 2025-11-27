# Agentbox

Agentbox is a Docker-based sandbox for running CLI agents (Codex, Claude Code) locally with strong isolation and easy access to your working directory.

## Features
- Debian-based sandbox (override with `--base`).
- Non-root execution with dropped capabilities; host workspace mounted at `/workspace`.
- Network allowlist enforced via a firewall namespace (OpenAI/Anthropic + ChatGPT/auth hosts by default); opt-in `--full-network` to bypass.
- Per-project/user config via `.agentbox/config.toml` / `~/.agentbox/config.toml` for allowlist entries.
- Optional toolkits installed at build time via `.agentbox/config.toml` / `~/.agentbox/config.toml` (default: none).
- Project `.agentbox` is mounted read-only in the sandbox to prevent in-container config tampering.
- Smoke-test harness (includes codex prompt check).

## Prerequisites
- Docker daemon available locally.

## Quick Start
1) Launch an agent
```bash
./bin/agentbox-codex
./bin/agentbox-claude -- bash -lc "ls -la"
# Run a one-off prompt non-interactively (uses codex exec)
./bin/agentbox-codex --prompt "List files"
```

### Authentication
- Configure host credential directories as needed (e.g., Codex `~/.codex`, Claude `~/.claude`). The launcher does not manage these paths; mount them manually if required.

### Networking
- Default egress is limited to Codex/Claude API hosts (`api.openai.com`, `platform.openai.com`, `chatgpt.com`, `chat.openai.com`, `auth.openai.com`, `api.anthropic.com`).
- Add hosts with a single list instead of repeated blocks:
  ```toml
  [network]
  allow_hosts = ["api.github.com", "registry.npmjs.org"]
  block_hosts = ["chatgpt.com"] # optional removals
  allow_file = "extra-hosts.txt" # optional, one host per line, # comments allowed (relative to config dir)
  ```
- Or run with `--full-network` to disable the firewall entirely.

### Default agent flags in the sandbox
- Codex runs with `--dangerously-bypass-approvals-and-sandbox` by default when launched via `agentbox-codex` (TTY sessions).
- Claude runs with `--dangerously-skip-permissions` by default when launched via `agentbox-claude` (TTY sessions).
These assume Docker already provides isolation and remove in-agent approval prompts.

### Flags and env vars
- `--base <image>` overrides the base image (pass after the shim, e.g., `agentbox-codex --base ubuntu:24.04`).
- `AGENTBOX_VERBOSE=1` streams Docker build output; `AGENTBOX_TTY=0|1|auto` controls TTY allocation.
- Allowlist resolution order: project `.agentbox/config.toml` takes priority over `~/.agentbox/config.toml`.

### Toolkits
- Select toolkits in `.agentbox/config.toml` (project) or `~/.agentbox/config.toml` (user) – defaults to none:
  ```toml
  [toolkits]
  selected = ["python", "c_cpp", "web"]
  ```
- Available toolkits:
  - `c_cpp`: build-essential, cmake, gdb
  - `python`: python3, pip, venv
  - `java`: default-jdk-headless
  - `web`: yarnpkg
  - `datascience`: numpy, pandas, scipy, matplotlib (Debian python3 packages)
- Toolkit selection is applied at image build; changing it triggers a rebuild (tag includes the selected toolkits).
- Quick helper: `bin/agentbox-setup` prompts and writes `.agentbox/config.toml` with selected toolkits.

### Legacy shims
- `bin/agentbox-run` still accepts an explicit agent argument if you prefer.

## Testing
```bash
./tests/smoke.sh           # quiet pass/fail summary
./tests/smoke.sh --verbose # detailed step output + container logs
./tests/allowlist_parse.sh # validate allowlist parsing without starting containers
./tests/setup.sh           # validates agentbox-setup writes expected config
```
The harness checks user identity, workspace access, network allowlist/override, codex prompt execution, CLI availability, and default launch.

## Project Layout
- `bin/agentbox-run` – launches agents.
- `docker/Dockerfile` – sandbox image definition.
- `docker/entrypoint.sh` – drops into the requested command.
- `tests/smoke.sh` – basic validation script.
- `specs/` – project requirements.
- `docs/security.md` – isolation guarantees and prompts-before-change policy.

[^openai-cli]: [OpenAI Codex CLI docs](https://developers.openai.com/codex/cli/)
[^claude-cli]: [Claude Code product page](https://www.claude.com/product/claude-code)
