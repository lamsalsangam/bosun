# Bosun ⚓

> **The ship's officer for your IT deck — scripts that keep things running.**

Bosun is a PowerShell module of real help-desk scripts: one-click health
reports, fixes for the classic ticket generators, and provisioning helpers.
Every command is something a support tech would actually run on a ticket —
no web UI, no dependencies, works offline.

<!-- TODO: terminal GIF of Get-BosunHealthReport -AsText -->

## Commands

| Command | What it fixes | Example |
| --- | --- | --- |
| `Get-BosunHealthReport` | "My computer is slow/broken" — one-click triage: OS/uptime, disks, memory, top processes, pending reboot, recent errors | `Get-BosunHealthReport -AsText` |
| `Reset-BosunPrintSpooler` | Stuck print queue — stop spooler, clear jobs, restart, verify | `Reset-BosunPrintSpooler -WhatIf` |
| `Clear-BosunDns` | "This website won't load" — flush the DNS cache, report entries cleared | `Clear-BosunDns` |
| `Reset-BosunNetwork` | "No internet" — DNS flush + DHCP renew (+ optional adapter restart) with before/after IP report | `Reset-BosunNetwork -AdapterName 'Wi-Fi'` |
| `Get-BosunSoftwareInventory` | "What's installed, what version?" — registry-based (no MSI self-repair), CSV export for asset tracking | `Get-BosunSoftwareInventory -Path inv.csv` |
| `New-BosunUser` | Onboarding — create local account, set groups, require password change at first logon | `New-BosunUser jdoe -Password $pw -RequirePasswordChange` |
| `Disable-BosunUser` | Offboarding — disable (not delete) and stamp the reason into the description | `Disable-BosunUser jdoe -Reason 'left - #4302'` |

All commands are Windows-first. Destructive ones support `-WhatIf`/`-Confirm`
and detect missing admin rights instead of crashing. Per-command details in
[`docs/`](docs/). Linux/macOS equivalents live in [`bash/`](bash/) —
currently `bosun-health-report.sh`.

## Install

No gallery, no dependencies — clone and import:

```powershell
git clone https://github.com/lamsalsangam/bosun.git
Import-Module ./bosun/Bosun/Bosun.psd1
```

Works on Windows PowerShell 5.1 and PowerShell 7+.

## Quick start

```powershell
# Triage a "my computer is slow" ticket
Get-BosunHealthReport

# Text report, ready to paste into ticket notes
Get-BosunHealthReport -AsText

# Save 3 days of history to a file for escalation
Get-BosunHealthReport -EventHours 72 -Path "$env:TEMP\health-$env:COMPUTERNAME.txt"
```

Every command ships with full help: `Get-Help Get-BosunHealthReport -Full`.

## Development

Tests use [Pester 5](https://pester.dev/):

```powershell
Invoke-Pester ./tests
```

## License

MIT
