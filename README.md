# Bosun ⚓

> **The ship's officer for your IT deck — scripts that keep things running.**

Bosun is a PowerShell module of real help-desk scripts: one-click health
reports, fixes for the classic ticket generators, and provisioning helpers.
Every command is something a support tech would actually run on a ticket —
no web UI, no dependencies, works offline.

<!-- TODO: terminal GIF of Get-BosunHealthReport -AsText -->

## Commands

| Command | What it does | Platform |
| --- | --- | --- |
| `Get-BosunHealthReport` | One-click system triage: OS/uptime, disks, memory, top processes, pending reboot, recent error events. Object output, or `-AsText` for pasting into a ticket. | Windows |

More on the way: print-spooler reset, DNS/network reset, software inventory,
user onboarding/offboarding. Linux/macOS equivalents live in [`bash/`](bash/)
where they make sense.

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
