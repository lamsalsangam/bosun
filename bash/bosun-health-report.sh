#!/bin/sh
# bosun-health-report.sh - one-click system health snapshot (Linux/macOS)
#
# The bash sibling of Get-BosunHealthReport: OS/uptime, disk space,
# memory, top processes, pending reboot, recent error logs. Plain text
# to stdout, ready to paste into a ticket.
#
# Usage:
#   ./bosun-health-report.sh            # print to stdout
#   ./bosun-health-report.sh > report.txt
#
# POSIX-leaning: uses only stock tools, degrades section-by-section when
# a tool is missing (e.g. no journalctl on macOS). No root required.

hr() { printf '%s\n' "======================================================================"; }
section() { printf '\n%s\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

EVENT_HOURS="${1:-24}"

hr
printf 'SYSTEM HEALTH REPORT - %s\n' "$(hostname)"
printf 'Generated: %s  (user: %s)\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$(id -un)"
hr

section "OPERATING SYSTEM"
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf '  %s\n' "${PRETTY_NAME:-$NAME}"
elif have sw_vers; then
    printf '  macOS %s (%s)\n' "$(sw_vers -productVersion)" "$(sw_vers -buildVersion)"
else
    printf '  %s\n' "$(uname -sr)"
fi
printf '  Kernel: %s\n' "$(uname -r)"
if have uptime; then
    printf '  Uptime:%s\n' "$(uptime | sed 's/.*up/ up/;s/,  *[0-9]* user.*//')"
fi

section "MEMORY"
if [ -r /proc/meminfo ]; then
    # MemAvailable needs kernel 3.14+; fall back to MemFree
    awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} /^MemFree:/ {f=$2}
         END { if (a == 0) a = f
               printf "  %.1f GB total, %.1f GB available (%d%% used)\n",
               t/1048576, a/1048576, (t-a)*100/t }' /proc/meminfo
elif have vm_stat; then
    # macOS: page counts -> GB
    total=$(sysctl -n hw.memsize 2>/dev/null)
    free_pages=$(vm_stat | awk '/Pages free/ {gsub("\\.",""); print $3}')
    page_size=$(vm_stat | head -1 | grep -o '[0-9]*')
    [ -n "$total" ] && printf '  %.1f GB total, %.1f GB free\n' \
        "$(echo "$total" | awk '{print $1/1073741824}')" \
        "$(echo "$free_pages $page_size" | awk '{print $1*$2/1073741824}')"
else
    printf '  (no memory info available)\n'
fi

section "DISKS"
# Local filesystems only; skip pseudo filesystems
df -h 2>/dev/null | awk 'NR==1 || $1 ~ /^\/dev\// {printf "  %s\n", $0}'

section "TOP PROCESSES (by memory)"
if ps aux --sort=-%mem >/dev/null 2>&1; then
    ps aux --sort=-%mem | head -6 | awk 'NR==1 {printf "  %-12s %-8s %5s %5s  %s\n", $1, $2, "%CPU", "%MEM", "COMMAND"; next}
        {printf "  %-12s %-8s %5s %5s  %s\n", $1, $2, $3, $4, $11}'
else
    # macOS/BSD ps has no --sort
    ps aux | sort -k4 -rn | head -5 | awk '{printf "  %-12s %-8s %5s %5s  %s\n", $1, $2, $3, $4, $11}'
fi

section "PENDING REBOOT"
if [ -f /var/run/reboot-required ]; then
    printf '  YES - /var/run/reboot-required exists\n'
    [ -r /var/run/reboot-required.pkgs ] && sed 's/^/    package: /' /var/run/reboot-required.pkgs
elif have needs-restarting; then
    # RHEL-family
    if needs-restarting -r >/dev/null 2>&1; then
        printf '  No\n'
    else
        printf '  YES - needs-restarting reports a reboot is required\n'
    fi
else
    printf '  No indicator found (or not applicable on this OS)\n'
fi

section "RECENT ERRORS (last ${EVENT_HOURS}h)"
if have journalctl; then
    journalctl -p err --since "${EVENT_HOURS} hours ago" --no-pager -q 2>/dev/null |
        tail -20 | sed 's/^/  /'
    [ -z "$(journalctl -p err --since "${EVENT_HOURS} hours ago" -q 2>/dev/null | head -1)" ] &&
        printf '  None found\n'
elif have log; then
    # macOS unified log (can be slow; keep the window tight)
    log show --last "${EVENT_HOURS}h" --predicate 'messageType == error' --style compact 2>/dev/null |
        tail -20 | sed 's/^/  /'
elif [ -r /var/log/syslog ]; then
    grep -iE 'error|crit|fail' /var/log/syslog | tail -20 | sed 's/^/  /'
else
    printf '  (no readable system log found)\n'
fi

printf '\n'
hr
