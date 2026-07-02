function Reset-BosunNetwork {
    <#
    .SYNOPSIS
        Resets the network stack for a "no internet" ticket: flushes DNS,
        renews DHCP leases, and optionally restarts the adapters. Reports
        what changed.

    .DESCRIPTION
        Works through the standard first-line network fixes in order and
        returns a per-adapter report of IP addresses before and after:

          1. Flush the DNS resolver cache
          2. Release/renew the DHCP lease on each matching adapter
             (adapters with static IPs are skipped and noted)
          3. With -RestartAdapters, disable/re-enable each adapter

        Requires an elevated session. WARNING: this interrupts network
        connectivity for a few seconds - do not run it over the same
        remote session you are working through unless you accept the
        drop. Supports -WhatIf/-Confirm.

    .PARAMETER AdapterName
        Adapter name or wildcard pattern to reset. Default: every
        connected physical adapter.

    .PARAMETER RestartAdapters
        Also disable/re-enable the matching adapters (the "unplug it and
        plug it back in" of NICs). Adds a few seconds of downtime per
        adapter.

    .EXAMPLE
        Reset-BosunNetwork

        Standard "no internet" ticket at the desk: flush DNS and renew
        DHCP on all connected adapters, then compare before/after IPs.

    .EXAMPLE
        Reset-BosunNetwork -AdapterName 'Wi-Fi' -RestartAdapters

        Wireless acting up: full reset of just the Wi-Fi adapter,
        including a disable/re-enable cycle.

    .OUTPUTS
        Bosun.NetworkResetResult (PSCustomObject)
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [string]$AdapterName = '*',

        [switch]$RestartAdapters
    )

    if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
        Write-Warning 'Reset-BosunNetwork is Windows-only.'
        return
    }

    if (-not (Test-BosunElevation)) {
        Write-Error 'Reset-BosunNetwork requires an elevated session (renewing DHCP leases and restarting adapters need admin rights). Re-run from an elevated PowerShell.'
        return
    }

    $adapters = @(Get-NetAdapter -Name $AdapterName -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up')
    if ($adapters.Count -eq 0) {
        Write-Error "No connected physical adapters match '$AdapterName'."
        return
    }

    $names = ($adapters.Name -join ', ')
    if (-not $PSCmdlet.ShouldProcess("Adapters: $names", 'Flush DNS, renew DHCP leases' + $(if ($RestartAdapters) { ', restart adapters' }))) {
        return
    }

    Write-Warning 'Network connectivity will be interrupted briefly.'

    Clear-DnsClientCache
    $adapterResults = New-Object System.Collections.Generic.List[object]

    foreach ($adapter in $adapters) {
        $ipBefore = @(Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress -join ', '

        $dhcpRenewed = $false
        $note = ''
        $config = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "InterfaceIndex = $($adapter.ifIndex)"
        if ($config -and $config.DHCPEnabled) {
            Invoke-BosunDhcpRenew -Configuration $config
            $dhcpRenewed = $true
        }
        else {
            $note = 'Static IP - DHCP renew skipped'
        }

        $restarted = $false
        if ($RestartAdapters) {
            Restart-NetAdapter -Name $adapter.Name -Confirm:$false
            $restarted = $true
        }

        $ipAfter = @(Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress -join ', '

        $adapterResults.Add([pscustomobject]@{
                Adapter     = $adapter.Name
                Description = $adapter.InterfaceDescription
                IPBefore    = $ipBefore
                IPAfter     = $ipAfter
                DhcpRenewed = $dhcpRenewed
                Restarted   = $restarted
                Note        = $note
            })
    }

    [pscustomobject]@{
        PSTypeName   = 'Bosun.NetworkResetResult'
        ComputerName = $env:COMPUTERNAME
        DnsFlushed   = $true
        Adapters     = $adapterResults.ToArray()
        Timestamp    = Get-Date
    }
}
