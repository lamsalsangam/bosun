function New-BosunUser {
    <#
    .SYNOPSIS
        Onboards a local user account: creates it, sets the password,
        adds it to groups, and optionally requires a password change at
        first logon.

    .DESCRIPTION
        Local-account onboarding in one step instead of four clicks in
        lusrmgr.msc. Creates the account, adds it to the given local
        groups (Users by default), and with -RequirePasswordChange flags
        it so the person sets their own password at first logon - the
        sane default when IT assigns a starter password.

        Requires an elevated session. Supports -WhatIf/-Confirm.
        Active Directory variants are out of scope for now; this is for
        workgroup/standalone machines.

    .PARAMETER Name
        Account name (SAM account rules: max 20 characters).

    .PARAMETER Password
        Starter password as a SecureString. Pair with
        -RequirePasswordChange so the user replaces it at first logon.

    .PARAMETER FullName
        Display name for the account.

    .PARAMETER Description
        Account description (team, role, ticket number).

    .PARAMETER Group
        Local groups to add the account to. Default: Users.

    .PARAMETER RequirePasswordChange
        Force a password change at first logon.

    .EXAMPLE
        New-BosunUser -Name jdoe -Password (Read-Host -AsSecureString 'Starter password') -FullName 'Jane Doe' -RequirePasswordChange

        Standard onboarding: prompt for the starter password (never in
        shell history), create the account, make Jane set her own
        password at first logon.

    .EXAMPLE
        New-BosunUser -Name kiosk01 -Password $pw -Description 'Deck 5 kiosk - ticket #4211' -Group 'Users','Remote Desktop Users'

        Kiosk/shared account that also needs RDP access.

    .OUTPUTS
        Bosun.UserResult (PSCustomObject)
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateLength(1, 20)]
        [string]$Name,

        [Parameter(Mandatory)]
        [securestring]$Password,

        [string]$FullName,

        [string]$Description,

        [string[]]$Group = @('Users'),

        [switch]$RequirePasswordChange
    )

    if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
        Write-Warning 'New-BosunUser is Windows-only.'
        return
    }

    if (-not (Get-Command New-LocalUser -ErrorAction SilentlyContinue)) {
        Write-Error 'The LocalAccounts cmdlets are not available on this system (Microsoft.PowerShell.LocalAccounts module).'
        return
    }

    if (-not (Test-BosunElevation)) {
        Write-Error 'New-BosunUser requires an elevated session (creating local accounts needs admin rights). Re-run from an elevated PowerShell.'
        return
    }

    if (Get-LocalUser -Name $Name -ErrorAction SilentlyContinue) {
        Write-Error "A local user named '$Name' already exists."
        return
    }

    if (-not $PSCmdlet.ShouldProcess("Local user '$Name' (groups: $($Group -join ', '))", 'Create account')) {
        return
    }

    $params = @{
        Name     = $Name
        Password = $Password
    }
    if ($FullName) { $params.FullName = $FullName }
    if ($Description) { $params.Description = $Description }

    $null = New-LocalUser @params -ErrorAction Stop

    $groupsAdded = New-Object System.Collections.Generic.List[string]
    foreach ($groupName in $Group) {
        try {
            Add-LocalGroupMember -Group $groupName -Member $Name -ErrorAction Stop
            $groupsAdded.Add($groupName)
        }
        catch {
            Write-Warning "Created the account but could not add it to '$groupName': $($_.Exception.Message)"
        }
    }

    if ($RequirePasswordChange) {
        Set-BosunPasswordChangeAtLogon -Name $Name
    }

    [pscustomobject]@{
        PSTypeName            = 'Bosun.UserResult'
        ComputerName          = $env:COMPUTERNAME
        Name                  = $Name
        FullName              = $FullName
        Groups                = $groupsAdded.ToArray()
        RequirePasswordChange = [bool]$RequirePasswordChange
        Created               = $true
    }
}
