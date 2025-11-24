# Installer Specification

## Goals
- Provide a single-shot installer usable via `curl | bash` that installs user-owned shims under `~/.agentbox/bin` and, when writable, drops trampolines into a PATH directory (e.g., `/usr/local/bin` on macOS/Linux). Everything else lives under a cache/checkout dir.
- Support two install sources:
  - Remote install from the main branch (GitHub tarball/zip).
  - Local install (dev mode) from an already-cloned working copy.
- Keep system prerequisites minimal: Docker and Python must already be present; fail fast if missing.
- No prebuilt images or bundled artifacts; always use source from the selected branch/tarball.
- Do not create `.agentbox` configs; leave that to `bin/agentbox-setup`.
- Platforms: macOS and Linux (Debian/Ubuntu); Windows/WSL out of scope.
- No uninstall/upgrade flow in this iteration; users can remove files manually if needed.
- No post-install tests; provide next-steps guidance instead.

## Behavior
1. **Prerequisite checks**
   - Verify `docker` is available and the daemon is reachable.
   - Verify `python3` is available (used by launcher/config parsing).
   - Warn/exit with clear messages if requirements are missing.

2. **Install targets**
   - User-owned shims live in `~/.agentbox/bin` (default).
   - Best-effort trampolines/symlinks into a PATH dir (default attempt: `/usr/local/bin`; overridable via `--prefix`). If not writable, emit a clear warning and suggest adding `~/.agentbox/bin` to PATH (instructions printed, no automatic edits).
   - Shims: `agentbox-codex`, `agentbox-claude`, `agentbox-run`, `agentbox-setup`, and minimal helper wrappers.
   - Repo/toolkit content lives under a managed install dir (e.g., `~/.agentbox/installs/<id>/`); shims point there.

3. **Sources / modes**
   - **Default (remote)**: fetch archive for the main branch from GitHub, extract to a versioned cache under `~/.agentbox/installs/<commit-or-date>/`, and link shims into `/usr/local/bin`.
   - **Local dev mode** (`--dev`): assume the script is run from an existing working copy; link shims in `/usr/local/bin` to this directory without downloading anything.
   - **Tarball input**: accept a `--tarball <url-or-path>` to install from a specific archive (e.g., release tarball). Behavior matches remote mode after extraction.

4. **Idempotency**
   - Re-running the installer should refresh links to the latest fetched/extracted path.
   - Existing shims should be overwritten with a prompt unless `--yes` is supplied.

5. **Non-goals (for this iteration)**
   - No uninstall command.
   - No upgrade/version pinning flags.
   - No automatic `.agentbox` creation or toolkit selection.
   - No automatic test execution post-install.

## CLI Sketch
- `install-agentbox.sh` (curl|bash entrypoint)
  - Flags:
    - `--prefix /usr/local/bin` (best-effort trampoline target; optional)
    - `--tarball <url-or-path>` (optional)
    - `--dev` (use current directory, no download)
    - `--yes` (non-interactive; overwrite existing links)
    - `--branch <name>` (optional, defaults to `main` when downloading)
  - Environment overrides allowed for automation: `AGENTBOX_PREFIX`, `AGENTBOX_TARBALL`, `AGENTBOX_BRANCH`, `AGENTBOX_DEV=1`, `AGENTBOX_YES=1`.

## Outputs / Messages
- On success: print install path, shim locations, and a short “next steps” (e.g., run `./tests/smoke.sh` from the repo and `bin/agentbox-setup` to create config).
- On failure: clear error messages for missing prerequisites or download/extract errors.

## Security / Safety
- Use HTTPS for remote downloads; validate expected archive layout before linking.
- No privilege escalation inside the script; assume the user runs with permissions to write to `--prefix`.
