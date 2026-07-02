# New-BosunUser / Disable-BosunUser

Local-account onboarding and offboarding for workgroup/standalone
machines. (Active Directory variants are on the roadmap; these commands
are deliberately local-only.)

## New-BosunUser — onboarding

Creates the account, adds it to groups (Users by default), and with
`-RequirePasswordChange` forces the person to set their own password at
first logon — the sane default when IT assigns a starter password.

```powershell
# Standard onboarding - password prompted, never in shell history
New-BosunUser -Name jdoe -FullName 'Jane Doe' -RequirePasswordChange `
    -Password (Read-Host -AsSecureString 'Starter password')

# Kiosk account that also needs RDP
New-BosunUser -Name kiosk01 -Password $pw `
    -Description 'Deck 5 kiosk - ticket #4211' `
    -Group 'Users','Remote Desktop Users'
```

## Disable-BosunUser — offboarding

Disables the account (never delete on day one — profile and files may
still be needed) and stamps the reason and date into the description so
the next tech knows the story.

```powershell
Disable-BosunUser -Name jdoe -Reason 'left company - ticket #4302'
```

The account description afterwards: `Disabled 2026-07-02: left company - ticket #4302`

## Notes

- Both **require an elevated session** and support `-WhatIf`/`-Confirm`.
- Account names are limited to 20 characters (SAM account rule).
- Windows-only.
