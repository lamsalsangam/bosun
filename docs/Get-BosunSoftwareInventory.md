# Get-BosunSoftwareInventory

Installed software with versions, publishers, and install dates — one
object per application, or straight to CSV for asset tracking.

## How it works

Reads the uninstall registry keys (64-bit, 32-bit/WOW6432Node, and
per-user HKCU) instead of `Win32_Product`, which is slow and triggers
MSI self-repair on every installed product — a classic support
foot-gun. System components are filtered out by default.

## Usage

```powershell
# Readable table of everything installed
Get-BosunSoftwareInventory | Format-Table Name, Version, Publisher

# Version check for an update/vulnerability ticket
Get-BosunSoftwareInventory -Name '*chrome*'

# Feed the asset-tracking share
Get-BosunSoftwareInventory -Path "\\fileserver\assets\$env:COMPUTERNAME.csv"

# Include runtimes/servicing entries too
Get-BosunSoftwareInventory -IncludeSystemComponents
```

## Notes

- No admin rights required.
- Per-user installs (HKCU) are only visible for the user running the
  command — worth remembering on shared machines.
- Windows-only; on Linux use the package manager (`dpkg -l`, `rpm -qa`).
