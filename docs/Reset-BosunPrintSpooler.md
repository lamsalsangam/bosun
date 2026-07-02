# Reset-BosunPrintSpooler

The classic fix for "my print job is stuck and nothing will print."

## What it does

1. Stops the **Print Spooler** service
2. Deletes stuck job files from `%SystemRoot%\System32\spool\PRINTERS`
3. Restarts the service and verifies it is running
4. Returns a result object: status before/after, jobs found, jobs cleared

## Usage

```powershell
# Interactive - shows what it found and asks before acting
Reset-BosunPrintSpooler

# Dry run: report how many stuck jobs would be cleared
Reset-BosunPrintSpooler -WhatIf

# No prompt - for scripted use after triage
Reset-BosunPrintSpooler -Force
```

## Notes

- **Requires an elevated session.** Without admin rights it explains why
  and makes no changes.
- Spool files that cannot be deleted (still locked) are reported as
  warnings; the service is restarted regardless, which usually releases
  the lock for a second run.
- Windows-only.
