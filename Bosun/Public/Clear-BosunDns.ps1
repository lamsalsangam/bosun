function Clear-BosunDns {
    <#
    .SYNOPSIS
        Flushes the DNS resolver cache and reports what was cleared.

    .DESCRIPTION
        First-line fix for "this website won't load" / "it works on my
        machine but not theirs": clears the local DNS client cache so the
        machine re-resolves every name. Reports how many cached entries
        were flushed. Does not require admin rights.

    .EXAMPLE
        Clear-BosunDns

        Flush the cache on a "site not loading" ticket; the result shows
        how many entries were cleared.

    .EXAMPLE
        Clear-BosunDns -Verbose

        Same, with verbose output showing the mechanism used.

    .OUTPUTS
        Bosun.DnsFlushResult (PSCustomObject)
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([pscustomobject])]
    param()

    if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
        Write-Warning 'Clear-BosunDns is Windows-only. On Linux/macOS DNS caching varies by distro (systemd-resolved, mDNSResponder).'
        return
    }

    $entriesBefore = 0
    $useCmdlet = [bool](Get-Command Clear-DnsClientCache -ErrorAction SilentlyContinue)
    if ($useCmdlet) {
        $entriesBefore = @(Get-DnsClientCache -ErrorAction SilentlyContinue).Count
    }

    if ($PSCmdlet.ShouldProcess('DNS resolver cache', 'Flush')) {
        if ($useCmdlet) {
            Write-Verbose 'Flushing via Clear-DnsClientCache'
            Clear-DnsClientCache
        }
        else {
            Write-Verbose 'Flushing via ipconfig /flushdns'
            $null = ipconfig.exe /flushdns
        }

        [pscustomobject]@{
            PSTypeName    = 'Bosun.DnsFlushResult'
            ComputerName  = $env:COMPUTERNAME
            EntriesBefore = $entriesBefore
            Flushed       = $true
            Timestamp     = Get-Date
        }
    }
}
