# Get-BosunHealthReport

One-click system health snapshot — the checks a tech runs first on a
"my computer is slow / broken" ticket, collected in one command.

## What it collects

- **OS**: edition, build, last boot time, uptime
- **Hardware**: manufacturer, model, logical processor count
- **Memory**: total / free / percent used
- **Disks**: every fixed drive with size, free space, and a low-space flag (<10% free)
- **Top processes** by memory (count configurable with `-TopProcessCount`)
- **Pending reboot**: the standard registry indicators (CBS, Windows Update,
  pending file renames, pending computer rename)
- **Recent errors**: critical/error events from the System and Application
  logs (window configurable with `-EventHours`, default 24h)

## Usage

```powershell
# Structured object - drill into sections
$health = Get-BosunHealthReport
$health.Disks
$health.RecentErrors | Where-Object Provider -eq 'Service Control Manager'

# Text report for ticket notes
Get-BosunHealthReport -AsText

# Longer event window, saved to a file for escalation
Get-BosunHealthReport -EventHours 72 -Path "$env:TEMP\health-$env:COMPUTERNAME.txt"
```

## Notes

- **No admin required.** Everything it reads is available to a standard
  user; the report records whether the session was elevated.
- **Windows-only** (CIM + Windows event log). On PowerShell 7 for
  Linux/macOS it exits with a warning.
- The `Security` event log is deliberately not queried — it requires
  elevation and is rarely relevant to first-line triage.
