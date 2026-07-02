function Test-BosunElevation {
    <#
    .SYNOPSIS
        Returns $true when the current PowerShell session is running elevated.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
        return $false
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
