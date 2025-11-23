#!/usr/bin/env bash
set -euo pipefail

log() {
  if [[ "${VERBOSE:-0}" == "1" ]]; then
    echo "agentbox-firewall: $*"
  fi
}

if ! command -v iptables >/dev/null 2>&1; then
  echo "agentbox-firewall: iptables not found" >&2
  exit 1
fi

ALLOW_HOSTS_RAW="${ALLOW_HOSTS:-}"
IFS=' ' read -r -a ALLOW_HOSTS <<<"${ALLOW_HOSTS_RAW}"

log "configuring firewall with allowlist: ${ALLOW_HOSTS_RAW:-<empty>}"

iptables -F
iptables -P OUTPUT DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP

# Allow loopback and established traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow DNS to configured resolvers so hostnames can resolve
mapfile -t DNS_SERVERS < <(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}')
if [[ ${#DNS_SERVERS[@]} -eq 0 ]]; then
  DNS_SERVERS=("127.0.0.11")
fi

for ns in "${DNS_SERVERS[@]}"; do
  iptables -A OUTPUT -p udp -d "${ns}" --dport 53 -j ACCEPT
  iptables -A OUTPUT -p tcp -d "${ns}" --dport 53 -j ACCEPT
  iptables -A INPUT -p udp -s "${ns}" --sport 53 -j ACCEPT
  iptables -A INPUT -p tcp -s "${ns}" --sport 53 -j ACCEPT
done

# Resolve allowed hosts and permit HTTPS egress to their IPs
if [[ ${#ALLOW_HOSTS[@]} -gt 0 ]]; then
  for host in "${ALLOW_HOSTS[@]}"; do
    [[ -z "${host}" ]] && continue
    mapfile -t HOST_IPS < <(getent ahostsv4 "${host}" | awk '{print $1}' | sort -u)
    if [[ ${#HOST_IPS[@]} -eq 0 ]]; then
      log "warning: unable to resolve ${host}; skipping"
      continue
    fi
    for ip in "${HOST_IPS[@]}"; do
      iptables -A OUTPUT -p tcp -d "${ip}" --dport 443 -j ACCEPT
    done
  done
fi

log "firewall ready; entering hold loop"
tail -f /dev/null
