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

`agentbox-setup` writes a TOML file at `.agentbox/config.toml`. Relevant sections:

```toml
[agents]
codex = true
claude = true

[network]
mode = "allowlist"         # future-proof; current release only supports allowlist
dns = ["8.8.8.8", "1.1.1.1"] # optional override; defaults to Docker-provided resolver

[[network.allow]]
host = "api.openai.com"

[[network.allow]]
host = "api.anthropic.com"

[[network.allow]]
host = "api.github.com"

[[network.block]]
host = "api.anthropic.com" # remove default host without editing built-in list
```

- `network.allow`: additive allowlist entries (domain names, optional port override later).
- `network.block`: entries removed from the effective allowlist.
- Hosts are resolved inside the firewall container before rules are applied; IPv4/IPv6 entries are both added.
- Empty allowlist ⇒ no outbound traffic.

## Runtime Architecture

1. `agentbox-run` reads `.agentbox/config.toml` and computes the effective allowlist:
   ```
   effective = (defaults ∪ network.allow) − network.block
   ```
2. `agentbox-run` creates a transient Docker network namespace by launching a short-lived **firewall container** with:
   - Base image: the same Agentbox image (so tooling is consistent).
   - Capabilities: `NET_ADMIN` only (other caps dropped).
   - Command:
     - Resolve each host using `getent ahosts` until at least one IP is found.
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
   - The existing hardening flags remain (read/write workspace mount, `--cap-drop ALL`, `--pids-limit`, `--security-opt no-new-privileges`); the only change is that we drop the `--network none` flag because traffic control is now handled by the shared firewall namespace.
5. When the agent exits, `agentbox-run` tears down both containers, removing the namespace.

## Prompt-Before-Change
- Any change to defaults (`api.openai.com`, `api.anthropic.com`), rule structure, or allowed ports must be recorded in this spec and announced to maintainers before merging.
- Contributors adding new default hosts must justify why they’re necessary and what data the host will receive.

## Open Questions / Future Work
- Rotate DNS resolutions periodically for hosts with large IP pools (e.g., Cloudflare) without widening the rule set too much.
- Support per-host port customization (`host = "sso.internal", ports = [443, 8443]`).
- Expose a dry-run mode that prints the final allowlist/IP table for auditing.

This spec complements `docs/security.md`; together they describe what outbound paths exist and how they’re controlled.
