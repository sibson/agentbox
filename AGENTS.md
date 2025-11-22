## Agent Guide

Welcome! This repo builds a Docker sandbox launcher plus tests. Follow the steps below when working on tasks here.

### 1. Review Specs First
- `specs/launch.md`: launcher expectations and acceptance criteria.
- `specs/docker.md`: isolation rules (no network, no root escalation).

### 2. Recommended Workflow
- Keep docs up to date (`README.md`, `docs/security.md`, relevant specs).
- Use the launcher shims: `bin/agentbox-codex` / `bin/agentbox-claude` to start agents.
- Mount host auth dirs manually if you need them inside the container.

### 3. Testing & Verification
- Run `./tests/smoke.sh` after meaningful Docker/launcher/config changes.
- Add new tests alongside new features when possible.

### 4. Safety & Constraints
- Do not loosen capability dropping or user restrictions without explicit approval and documentation updates.
- Stay within a minimal dependency footprint unless justified.

Questions or unexpected states? Document them in your response so maintainers can follow up.
