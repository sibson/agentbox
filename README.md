# Agentbox

Agentbox is a Docker-based sandbox for running CLI agents (Codex, Claude Code) locally with strong isolation and easy access to your working directory.

## Features
- Debian-based sandbox, base image override via `--base`.
- Non-root execution with capabilities dropped; host workspace mounted at `/workspace`.
- Network allowlist by default (OpenAI/Anthropic endpoints); opt-in `--full-network` to bypass.
- Simple smoke-test harness.

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
- Add hosts to the allowlist in `.agentbox` (project) or `~/.agentbox` (user):
  ```toml
  [[network.allow]]
  host = "api.github.com"
  ```
- Remove hosts with `[[network.block]]` entries, or run with `--full-network` to disable the firewall entirely.

### Default agent flags in the sandbox
- Codex runs with `--dangerously-bypass-approvals-and-sandbox` by default when launched via `agentbox-codex` (TTY sessions).
- Claude runs with `--dangerously-skip-permissions` by default when launched via `agentbox-claude` (TTY sessions).
These assume Docker already provides isolation and remove in-agent approval prompts.

### Flags and env vars
- `--base <image>` overrides the base image (pass after the shim, e.g., `agentbox-codex --base ubuntu:24.04`).
- `AGENTBOX_VERBOSE=1` streams Docker build output; `AGENTBOX_TTY=0|1|auto` controls TTY allocation.

### Legacy shims
- `bin/agentbox-run` still accepts an explicit agent argument if you prefer.

## Testing
```bash
./tests/smoke.sh           # quiet pass/fail summary
./tests/smoke.sh --verbose # detailed step output + container logs
```
The harness checks user identity, workspace access, CLI availability, and default launch.

## Project Layout
- `bin/agentbox-run` – launches agents.
- `docker/Dockerfile` – sandbox image definition.
- `docker/entrypoint.sh` – drops into the requested command.
- `tests/smoke.sh` – basic validation script.
- `specs/` – project requirements.
- `docs/security.md` – isolation guarantees and prompts-before-change policy.

[^openai-cli]: [OpenAI Codex CLI docs](https://developers.openai.com/codex/cli/)
[^claude-cli]: [Claude Code product page](https://www.claude.com/product/claude-code)
