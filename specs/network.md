# Network Connectivity Spec

## Goals
- Maintain the sandbox isolation guarantees from `specs/docker.md` while enabling agent CLIs that require outbound access to a small set of SaaS APIs.
- Provide a declarative, auditable configuration so users know exactly which hosts are reachable.
- Require explicit approval/documentation before modifying default rules.

## Default Policy
- The sandbox starts with **no outbound connectivity**.
- Agentbox will build a per-session allowlist enforced by `iptables` inside the container namespace.
- Default allowlist hosts (applied unless explicitly blocklisted):
  - `api.openai.com`
  - `platform.openai.com`
  - `chatgpt.com`
  - `chat.openai.com`
  - `auth.openai.com`
  - `api.anthropic.com`
- DNS traffic is restricted to the container’s resolver (typically Docker’s embedded DNS) and only for domains in the current allowlist set.
- Operators can bypass the firewall intentionally with `--full-network` (bridge networking, no allowlist).

## `.agentbox` Configuration

`agentbox-setup` writes a TOML file at `.agentbox/config.toml` (project root) or, if absent, uses `~/.agentbox/config.toml`. Relevant sections:

```toml
[network]
mode = "allowlist"
allow_hosts = ["api.github.com", "registry.npmjs.org"]
block_hosts = ["chatgpt.com"] # optional removals from defaults
allow_file = "extra-hosts.txt" # optional file, one host per line, '#' comments allowed (relative to config directory)
```

- `network.allow_hosts`: additive allowlist entries (domain names, optional port override later).
- `network.block_hosts`: entries removed from the effective allowlist (useful to drop defaults); glob patterns are supported (e.g., `*.openai.com` removes all matching entries).
- `network.allow_file`: optional path to a file containing one host per line; resolved relative to the config file directory unless absolute; blank lines and `#` comments are ignored.
- Hosts are resolved inside the firewall container before rules are applied; IPv4/IPv6 entries are both added.
- Empty allowlist ⇒ no outbound traffic.
- Wildcards are supported in `allow_hosts`/`allow_file` entries: `*.example.com` is treated as a domain suffix and resolved via the apex plus a synthetic probe (`agentbox-wildcard-probe.example.com`) so wildcard DNS records can be captured.

## Runtime Architecture

1. `agentbox-run` reads `.agentbox/config.toml` and computes the effective allowlist:
   ```
   effective = (defaults ∪ network.allow_hosts ∪ hosts_from_allow_file) − network.block_hosts
   ```
2. `agentbox-run` creates a transient Docker network namespace by launching a short-lived **firewall container** with:
   - Base image: the same Agentbox image (so tooling is consistent).
   - Capabilities: `NET_ADMIN` only (other caps dropped).
   - Command:
     - Resolve each host using `getent ahosts` until at least one IP is found; for wildcard entries (`*.domain.tld`), try both the apex and `agentbox-wildcard-probe.<suffix>` to catch wildcard DNS targets.
     - Program `iptables` rules:
       - Flush existing rules.
       - Default policies: `INPUT ACCEPT`, `FORWARD DROP`, `OUTPUT DROP`.
       - Allow loopback traffic.
       - Allow DNS lookups to the Docker resolver IP(s).
       - For each allowed IP: permit `OUTPUT` TCP/443 (and TCP/80 if a host entry specifies `http` explicitly).
     - Optionally retry resolution on a schedule (future enhancement) for hosts with rotating IPs.
3. The firewall container keeps running, holding the network namespace alive.
4. `agentbox-run` starts the actual agent container with:
   - `--network container:<firewall-container-id>` so it shares the namespace and inherits the programmed rules.
   - The existing hardening flags remain (read/write workspace mount with `.agentbox` over-mounted read-only, `--cap-drop ALL`, `--pids-limit`, `--security-opt no-new-privileges`); the only change is that we drop the `--network none` flag because traffic control is now handled by the shared firewall namespace.
5. When the agent exits, `agentbox-run` tears down both containers, removing the namespace.

## Prompt-Before-Change
- Any change to defaults (`api.openai.com`, `api.anthropic.com`), rule structure, or allowed ports must be recorded in this spec and announced to maintainers before merging.
- Contributors adding new default hosts must justify why they’re necessary and what data the host will receive.

## Open Questions / Future Work
- Rotate DNS resolutions periodically for hosts with large IP pools (e.g., Cloudflare) without widening the rule set too much.
- Support per-host port customization (`host = "sso.internal", ports = [443, 8443]`).
- Expose a dry-run mode that prints the final allowlist/IP table for auditing.

This spec complements `docs/security.md`; together they describe what outbound paths exist and how they’re controlled.
