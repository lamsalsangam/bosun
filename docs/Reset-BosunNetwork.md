# Clear-BosunDns / Reset-BosunNetwork

First-line network fixes, from mild to firm.

## Clear-BosunDns

Flushes the DNS resolver cache and reports how many entries were
cleared. The fix for "this website won't load" when everything else
works. No admin rights needed.

```powershell
Clear-BosunDns
```

## Reset-BosunNetwork

The full "no internet" sequence with a before/after report per adapter:

1. Flush DNS cache
2. Release/renew the DHCP lease on each connected physical adapter
   (static-IP adapters are skipped and noted in the report)
3. With `-RestartAdapters`, disable/re-enable each adapter

```powershell
# All connected adapters
Reset-BosunNetwork

# Just Wi-Fi, including a disable/re-enable cycle
Reset-BosunNetwork -AdapterName 'Wi-Fi' -RestartAdapters

# Dry run
Reset-BosunNetwork -WhatIf
```

## Notes

- `Reset-BosunNetwork` **requires an elevated session** and briefly
  interrupts connectivity — don't run it over the remote session you
  are working through unless you accept the drop. `ConfirmImpact` is
  High, so it prompts by default; use `-Confirm:$false` in scripts.
- Both commands are Windows-only.
