#!/bin/sh
# bosun-dns-flush.sh - flush the DNS resolver cache (Linux/macOS)
#
# The bash sibling of Clear-BosunDns. Detects which resolver/cache the
# system runs and flushes it. First-line fix for "this website won't
# load" when connectivity is otherwise fine.
#
# Usage:
#   ./bosun-dns-flush.sh
#
# Needs sudo on most systems (restarting/toggling the resolver cache).

have() { command -v "$1" >/dev/null 2>&1; }

if have resolvectl; then
    # systemd-resolved (most modern Linux)
    resolvectl flush-caches && echo "Flushed systemd-resolved cache." && exit 0
    echo "resolvectl failed - try: sudo resolvectl flush-caches" >&2
    exit 1
elif have systemd-resolve; then
    # older systemd
    systemd-resolve --flush-caches && echo "Flushed systemd-resolved cache." && exit 0
    echo "systemd-resolve failed - try with sudo" >&2
    exit 1
elif have dscacheutil; then
    # macOS
    dscacheutil -flushcache && killall -HUP mDNSResponder 2>/dev/null
    echo "Flushed macOS DNS cache (dscacheutil + mDNSResponder)."
    exit 0
elif have rndc; then
    # local BIND named
    rndc flush && echo "Flushed BIND (named) cache." && exit 0
    echo "rndc failed - try with sudo" >&2
    exit 1
elif have nscd; then
    # legacy nscd
    nscd -i hosts && echo "Flushed nscd hosts cache." && exit 0
    echo "nscd failed - try: sudo nscd -i hosts" >&2
    exit 1
else
    echo "No known DNS cache found (systemd-resolved, macOS, BIND, nscd)." >&2
    echo "This system may not cache DNS locally - nothing to flush." >&2
    exit 0
fi
