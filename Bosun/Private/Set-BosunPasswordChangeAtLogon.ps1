function Set-BosunPasswordChangeAtLogon {
    <#
    .SYNOPSIS
        Flags a local account so the user must change their password at
        next logon. Split out because New-LocalUser has no parameter for
        this; it needs net.exe, and callers are easier to test with the
        call isolated here.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $null = net.exe user $Name /logonpasswordchg:yes
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not set 'must change password at next logon' for $Name (net.exe exit code $LASTEXITCODE)."
    }
}
