#!/bin/sh
# bosun-software-inventory.sh - installed software with versions (Linux/macOS)
#
# The bash sibling of Get-BosunSoftwareInventory. Detects the package
# manager and prints "name<TAB>version" lines, ready for sort/grep or
# redirecting to a file for asset tracking.
#
# Usage:
#   ./bosun-software-inventory.sh                 # full inventory
#   ./bosun-software-inventory.sh chrome          # filter (case-insensitive)
#   ./bosun-software-inventory.sh > inventory.tsv
#
# No root required.

FILTER="$1"

have() { command -v "$1" >/dev/null 2>&1; }

inventory() {
    if have dpkg-query; then
        # Debian/Ubuntu
        dpkg-query -W -f '${Package}\t${Version}\n' 2>/dev/null
    elif have rpm; then
        # RHEL/Fedora/SUSE
        rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\n' 2>/dev/null
    elif have pacman; then
        # Arch
        pacman -Q 2>/dev/null | tr ' ' '\t'
    elif have apk; then
        # Alpine
        apk info -v 2>/dev/null | sed 's/-\([0-9][^-]*-r[0-9]*\)$/\t\1/'
    elif have brew; then
        # macOS Homebrew
        brew list --versions 2>/dev/null | sed 's/ /\t/'
    else
        echo "bosun-software-inventory: no supported package manager found (dpkg, rpm, pacman, apk, brew)" >&2
        exit 1
    fi
}

if [ -n "$FILTER" ]; then
    inventory | grep -i -- "$FILTER"
else
    inventory
fi | sort -f
