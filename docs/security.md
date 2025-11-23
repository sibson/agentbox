# Agentbox Security & Sandboxing Overview

This document captures the current security posture of Agentbox so contributors understand what guarantees we provide and which trade-offs we have accepted. Any proposal to loosen these guarantees **must be discussed with the maintainers first**—always prompt the team before changing these rules.

## Goals
- Allow CLI agents (Codex, Claude Code) to work inside an isolated container that mirrors the developer’s workspace.
- Prevent the agent from gaining additional privileges (e.g., root escalation) while keeping outbound access constrained to a small, auditable allowlist (with an explicit escape hatch).
- Make host access explicit and easy to audit.

## Container Isolation Decisions

| Area | Current Design | Rationale |
| --- | --- | --- |
| Base image | Debian bookworm slim (override via `--base`) | Minimal attack surface with familiar tooling; supports multiple distros when needed. |
| User model | Non-root `agent` user with home dir `/home/agent` | Limits impact of agent compromise; aligns with no-root spec. |
| Capabilities | All Linux capabilities dropped (`--cap-drop ALL`) + `--security-opt no-new-privileges` | Prevents privilege escalation via ambient caps or setuid binaries. |
| Process limits | `--pids-limit 512` | Mitigates fork bombs / runaway workloads. |
| Networking | Dedicated firewall container programs iptables allowlist; agent container joins its namespace | Allows tight egress control (OpenAI/Anthropic by default) without granting NET_ADMIN to the agent. |
| Filesystem | Host project mounted read/write at `/workspace` | Gives agents the working tree while keeping other host paths out of scope. |
| Agent configs | Mount host credential/config directories manually if needed. | Keeps auth outside the image. |
| Entry point | `agent-entrypoint` launches the requested agent CLI only when a TTY is available; otherwise falls back to `/bin/bash`. | Prevents non-interactive tasks from blocking waiting for UI input while keeping default UX for humans. |

## Authentication Data Flow
- Codex and Claude store login material under the user’s home directory (e.g., `~/.codex`, `~/.claude`).
- Mount host auth directories manually when needed so the agent inherits existing sessions.
- Never bake API keys into the image.

## Current Host Access Allowances
- `/workspace`: bind-mounted working tree (read/write).
- No other host paths are mounted by default; mount auth dirs manually if needed.

## Network and Capability Posture
- Network: iptables allowlist (defaults: `api.openai.com`, `platform.openai.com`, `chatgpt.com`, `chat.openai.com`, `auth.openai.com`, `api.anthropic.com`); `--full-network` bypasses it.
- Capabilities: `--cap-drop ALL`, `--security-opt no-new-privileges`.
- User: non-root `agent`.

Default in-agent approval settings
- Codex: `--dangerously-bypass-approvals-and-sandbox`.
- Claude: `--dangerously-skip-permissions`.

## Prompt-Before-Change Policy
- Any change that **broadens access** (re-enabling networking, adding new mounts, increasing kernel capabilities, etc.) requires a design discussion.
- Update this document and the specs before shipping such changes.
- Mention the rationale, mitigations, and testing plan when proposing adjustments.

## Testing Expectations
- Run `./tests/smoke.sh` after changes touching Dockerfiles, launcher flags, or config handling.
- Add new tests for any additional isolation features (e.g., verifying new mounts, confirming network remains blocked).

Keeping this document current makes it easier for reviewers and future contributors to understand why the sandbox looks the way it does, and ensures we don’t erode safety inadvertently. Always surface questions/concerns early if a feature seems to conflict with these principles.
