function Disable-BosunUser {
    <#
    .SYNOPSIS
        Offboards a local user account: disables it and stamps the
        reason into the account description.

    .DESCRIPTION
        Disables the account (offboarding first step - never delete on
        day one; the mailbox, profile, and files may still be needed)
        and, with -Reason, records why and when in the account
        description so the next tech knows the story.

        Requires an elevated session. Supports -WhatIf/-Confirm.

    .PARAMETER Name
        The local account to disable.

    .PARAMETER Reason
        Short reason stamped into the account description together with
        the date, e.g. "left company - ticket #4302".

    .EXAMPLE
        Disable-BosunUser -Name jdoe -Reason 'left company - ticket #4302'

        Standard offboarding: disable and document why.

    .EXAMPLE
        Disable-BosunUser -Name kiosk01 -WhatIf

        Check what would happen before touching a shared account.

    .OUTPUTS
        Bosun.UserResult (PSCustomObject)
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [string]$Reason
    )

    if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
        Write-Warning 'Disable-BosunUser is Windows-only.'
        return
    }

    if (-not (Get-Command Disable-LocalUser -ErrorAction SilentlyContinue)) {
        Write-Error 'The LocalAccounts cmdlets are not available on this system (Microsoft.PowerShell.LocalAccounts module).'
        return
    }

    if (-not (Test-BosunElevation)) {
        Write-Error 'Disable-BosunUser requires an elevated session. Re-run from an elevated PowerShell.'
        return
    }

    $user = Get-LocalUser -Name $Name -ErrorAction SilentlyContinue
    if (-not $user) {
        Write-Error "No local user named '$Name' was found."
        return
    }

    if (-not $PSCmdlet.ShouldProcess("Local user '$Name' (currently enabled: $($user.Enabled))", 'Disable account')) {
        return
    }

    $wasEnabled = $user.Enabled
    Disable-LocalUser -Name $Name -ErrorAction Stop

    if ($Reason) {
        $stamp = "Disabled $(Get-Date -Format 'yyyy-MM-dd'): $Reason"
        try {
            Set-LocalUser -Name $Name -Description $stamp -ErrorAction Stop
        }
        catch {
            Write-Warning "Account disabled, but the description could not be updated: $($_.Exception.Message)"
        }
    }

    [pscustomobject]@{
        PSTypeName   = 'Bosun.UserResult'
        ComputerName = $env:COMPUTERNAME
        Name         = $Name
        WasEnabled   = $wasEnabled
        Enabled      = $false
        Reason       = $Reason
        Disabled     = $true
    }
}
