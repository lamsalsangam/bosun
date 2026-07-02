function Test-BosunPendingReboot {
    <#
    .SYNOPSIS
        Checks the standard registry locations that indicate Windows is
        waiting for a reboot. Returns an object with IsPending and the
        list of reasons found.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $reasons = New-Object System.Collections.Generic.List[string]

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $reasons.Add('Component Based Servicing (Windows updates)')
    }

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $reasons.Add('Windows Update reboot required')
    }

    $sessionManager = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
    if ($sessionManager -and $sessionManager.PendingFileRenameOperations) {
        $reasons.Add('Pending file rename operations')
    }

    $activeName = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -ErrorAction SilentlyContinue).ComputerName
    $pendingName = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -ErrorAction SilentlyContinue).ComputerName
    if ($activeName -and $pendingName -and $activeName -ne $pendingName) {
        $reasons.Add("Computer rename pending ($activeName -> $pendingName)")
    }

    [pscustomobject]@{
        IsPending = ($reasons.Count -gt 0)
        Reasons   = @($reasons)
    }
}
