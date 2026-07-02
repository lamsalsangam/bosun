function Get-BosunSoftwareInventory {
    <#
    .SYNOPSIS
        Lists installed software with versions, publishers, and install
        dates - from the registry, without triggering MSI repair.

    .DESCRIPTION
        Reads the uninstall registry keys (64-bit, 32-bit, and per-user)
        rather than querying Win32_Product, which is slow and can trigger
        MSI self-repair on every product. Returns one object per
        application, ready to feed asset tracking; use -Path to export
        straight to CSV.

        System components and hotfix-style entries are filtered out by
        default; include them with -IncludeSystemComponents.

    .PARAMETER Name
        Only return applications whose display name matches this wildcard
        pattern (e.g. 'Microsoft*').

    .PARAMETER IncludeSystemComponents
        Also include entries flagged as system components (runtime
        redistributables, servicing entries, and similar).

    .PARAMETER Path
        Export the inventory to this CSV file as well as returning it.

    .EXAMPLE
        Get-BosunSoftwareInventory | Sort-Object Name | Format-Table Name, Version, Publisher

        Readable inventory of everything installed on the machine.

    .EXAMPLE
        Get-BosunSoftwareInventory -Name '*chrome*'

        "What version of Chrome is on this machine?" - version check for
        a vulnerability advisory or update ticket.

    .EXAMPLE
        Get-BosunSoftwareInventory -Path "\\fileserver\assets\$env:COMPUTERNAME.csv"

        Export the machine's inventory to the asset-tracking share.

    .OUTPUTS
        Bosun.SoftwareEntry (PSCustomObject), one per application.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Name = '*',

        [switch]$IncludeSystemComponents,

        [string]$Path
    )

    if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
        Write-Warning 'Get-BosunSoftwareInventory is Windows-only. On Linux use the package manager (dpkg -l / rpm -qa).'
        return
    }

    $registryPaths = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'; Scope = 'Machine'; Architecture = '64-bit' }
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'; Scope = 'Machine'; Architecture = '32-bit' }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'; Scope = 'User'; Architecture = '' }
    )

    $inventory = foreach ($location in $registryPaths) {
        $entries = Get-ItemProperty -Path $location.Path -ErrorAction SilentlyContinue
        foreach ($entry in $entries) {
            if (-not $entry.DisplayName) { continue }
            if ($entry.DisplayName -notlike $Name) { continue }
            if (-not $IncludeSystemComponents -and $entry.SystemComponent -eq 1) { continue }

            $installDate = $null
            if ($entry.InstallDate -match '^\d{8}$') {
                try {
                    $installDate = [datetime]::ParseExact($entry.InstallDate, 'yyyyMMdd', $null)
                }
                catch {
                    # leave $null - some installers write junk here
                }
            }

            [pscustomobject]@{
                PSTypeName   = 'Bosun.SoftwareEntry'
                Name         = $entry.DisplayName
                Version      = $entry.DisplayVersion
                Publisher    = $entry.Publisher
                InstallDate  = $installDate
                Scope        = $location.Scope
                Architecture = $location.Architecture
                UninstallKey = $entry.PSChildName
            }
        }
    }

    # Same product can appear under both HKLM and HKCU; keep everything but sort stably
    $inventory = @($inventory | Sort-Object Name, Version)

    if ($Path) {
        $inventory | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
        Write-Verbose "Exported $($inventory.Count) entries to $Path"
    }

    $inventory
}
