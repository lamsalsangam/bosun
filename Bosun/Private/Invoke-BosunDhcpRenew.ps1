function Invoke-BosunDhcpRenew {
    <#
    .SYNOPSIS
        Releases and renews the DHCP lease on one network adapter
        configuration (Win32_NetworkAdapterConfiguration instance).
        Split out so callers can be tested without touching CIM.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Configuration
    )

    $null = Invoke-CimMethod -InputObject $Configuration -MethodName ReleaseDHCPLease
    $null = Invoke-CimMethod -InputObject $Configuration -MethodName RenewDHCPLease
}
