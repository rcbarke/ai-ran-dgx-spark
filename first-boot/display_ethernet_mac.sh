#!/usr/bin/env bash
# display_ethernet_mac.sh
# List physical Ethernet NICs for registration (DGX Spark friendly).
# Register at netregistration.clemson.edu
#
# Skips Wi-Fi, Docker/bridge/veth/tunnel/loopback interfaces.
# Optional:
#   --list      : print MACs only (one per line)
#   --json      : print JSON (requires jq if you want to pretty-print)
#   --help/-h   : usage

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: display_ethernet_mac.sh [--list|--json]

Lists physical Ethernet interfaces with:
  - Interface name
  - MAC address
  - IPv4 address (if any)
  - Driver and link speed (if available)
  - PCI address and lspci description (if available)

Options:
  --list   Print MAC addresses only (one per line)
  --json   Print JSON
  -h, --help  Show this help
EOF
}

mode="table"
case "${1-}" in
  --list) mode="list" ;;
  --json) mode="json" ;;
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
esac

# Interface name patterns to ignore (virtuals/tunnels/bridges/etc.)
IGNORE_REGEX='^(lo|docker.*|br-.*|veth.*|virbr.*|nm-.*|vlan.*|svlan.*|tun.*|tap.*|gre.*|gretap.*|ip6gre.*|ip6tnl.*|sit.*|dummy.*|bond.*|team.*|cni.*|flannel.*|zt.*)$'

# Helper: safe read a file
readf() { local f="$1"; [[ -r "$f" ]] && tr -d '\n' < "$f" || true; }

# Collect candidate NICs from /sys (more reliable than parsing ip output for physicality)
interfaces=()
for d in /sys/class/net/*; do
  [[ -e "$d" ]] || continue
  ifname="$(basename "$d")"

  # Skip known virtual/loopback/tunnel patterns
  if [[ "$ifname" =~ $IGNORE_REGEX ]]; then
    continue
  fi

  # Must be Ethernet (type 1) and not wireless (presence of /wireless indicates Wi-Fi)
  # /sys/class/net/<if>/type == 1 means ARPHRD_ETHER
  if [[ -f "$d/type" ]]; then
    if [[ "$(readf "$d/type")" != "1" ]]; then
      continue
    fi
  fi
  if [[ -d "$d/wireless" ]]; then
    # Wi-Fi — skip
    continue
  fi

  # Prefer physical (PCI) devices: /sys/class/net/<if>/device exists
  if [[ ! -e "$d/device" ]]; then
    # Likely a virtual/bridge, skip
    continue
  fi

  interfaces+=("$ifname")
done

# Gather facts per interface
rows=()
json_items=()

for ifname in "${interfaces[@]}"; do
  sys="/sys/class/net/$ifname"

  mac="$(readf "$sys/address")"
  [[ -n "$mac" && "$mac" != "00:00:00:00:00:00" ]] || mac=""

  # IPv4 (first)
  ipv4="$(ip -4 -o addr show dev "$ifname" 2>/dev/null | awk '{print $4}' | sed 's#/.*##' | head -n1)"
  [[ -n "$ipv4" ]] || ipv4="-"

  # Driver + speed (best effort)
  driver=""
  speed=""
  if command -v ethtool >/dev/null 2>&1; then
    driver="$(ethtool -i "$ifname" 2>/dev/null | awk -F': ' '/^driver:/{print $2}' || true)"
    speed="$(ethtool "$ifname" 2>/dev/null | awk -F': ' '/Speed:/{print $2}' || true)"
  fi
  [[ -n "$driver" ]] || driver="-"
  [[ -n "$speed" ]] || speed="-"

  # PCI address + lspci description (if any)
  pci_addr=""
  pci_desc="-"
  if [[ -e "$sys/device" ]]; then
    # Resolve to .../0000:bb:dd.f
    devpath="$(readlink -f "$sys/device" || true)"
    pci_addr="$(basename "$devpath" 2>/dev/null || true)"
    # On some systems the basename might be "net" if not resolved; guard:
    if [[ "$pci_addr" != "device" && "$pci_addr" != "net" && "$pci_addr" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F]$ ]]; then
      if command -v lspci >/dev/null 2>&1; then
        pci_desc="$(lspci -s "$pci_addr" 2>/dev/null | sed 's/^[^ ]\+ //')"
        [[ -n "$pci_desc" ]] || pci_desc="-"
      fi
    else
      pci_addr="-"
    fi
  fi
  [[ -n "$pci_addr" ]] || pci_addr="-"

  # Build outputs
  case "$mode" in
    list)
      [[ -n "$mac" ]] && echo "$mac"
      ;;
    json)
      json_items+=("{\"iface\":\"$ifname\",\"mac\":\"$mac\",\"ipv4\":\"$ipv4\",\"driver\":\"$driver\",\"speed\":\"$speed\",\"pci\":\"$pci_addr\",\"desc\":\"$pci_desc\"}")
      ;;
    table)
      rows+=("$ifname|$mac|$ipv4|$driver|$speed|$pci_addr|$pci_desc")
      ;;
  esac
done

if [[ "$mode" == "json" ]]; then
  echo "["$(IFS=, ; echo "${json_items[*]}")"]"
elif [[ "$mode" == "table" ]]; then
  # Pretty table
  printf "%-12s %-19s %-15s %-14s %-10s %-14s %s\n" "IFACE" "MAC" "IPv4" "DRIVER" "SPEED" "PCI" "DESCRIPTION"
  printf "%-12s %-19s %-15s %-14s %-10s %-14s %s\n" "------------" "-------------------" "---------------" "--------------" "----------" "--------------" "-----------"
  for line in "${rows[@]}"; do
    IFS='|' read -r iface mac ipv4 driver speed pci desc <<<"$line"
    printf "%-12s %-19s %-15s %-14s %-10s %-14s %s\n" "$iface" "$mac" "$ipv4" "$driver" "$speed" "$pci" "$desc"
  done

  echo
  echo "Copy/paste into netregistration.clemson.edu (MACs only):"
  echo "  $0 --list"
fi

