function Reset-BosunPrintSpooler {
    <#
    .SYNOPSIS
        Fixes a stuck print queue: stops the Print Spooler service, clears
        stuck jobs from the spool directory, and restarts the service.

    .DESCRIPTION
        The standard fix for "my print job is stuck and nothing will
        print". Stops the Spooler service, deletes the queued job files
        from the spool directory, starts the service again, and verifies
        it is running. Returns an object describing what was done.

        Requires an elevated session (stopping services and clearing the
        spool directory need admin rights); if the session is not
        elevated the function reports it and makes no changes. Supports
        -WhatIf/-Confirm.

    .PARAMETER Force
        Skip the confirmation prompt (equivalent to -Confirm:$false).

    .EXAMPLE
        Reset-BosunPrintSpooler

        Standard stuck-queue ticket: prompts for confirmation, then
        clears the queue and restarts the spooler.

    .EXAMPLE
        Reset-BosunPrintSpooler -WhatIf

        Show what would be done (how many stuck jobs would be cleared)
        without changing anything.

    .EXAMPLE
        Reset-BosunPrintSpooler -Force

        Same fix without the confirmation prompt - for scripted use
        against a machine you have already triaged.

    .OUTPUTS
        Bosun.SpoolerResetResult (PSCustomObject)
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [switch]$Force
    )

    if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
        Write-Warning 'Reset-BosunPrintSpooler is Windows-only.'
        return
    }

    if (-not (Test-BosunElevation)) {
        Write-Error 'Reset-BosunPrintSpooler requires an elevated session (stopping services and clearing the spool directory need admin rights). Re-run from an elevated PowerShell.'
        return
    }

    $service = Get-Service -Name Spooler -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Error 'The Print Spooler (Spooler) service was not found on this machine.'
        return
    }

    $spoolPath = Join-Path $env:SystemRoot 'System32\spool\PRINTERS'
    $stuckJobs = @(Get-ChildItem -Path $spoolPath -File -ErrorAction SilentlyContinue)

    $target = "Print Spooler (status: $($service.Status), stuck job files: $($stuckJobs.Count))"
    if ($Force -or $PSCmdlet.ShouldProcess($target, 'Stop service, clear spool directory, restart')) {

        $statusBefore = $service.Status

        if ($service.Status -ne 'Stopped') {
            Stop-Service -Name Spooler -Force -ErrorAction Stop
        }

        $cleared = 0
        foreach ($job in $stuckJobs) {
            try {
                Remove-Item -LiteralPath $job.FullName -Force -ErrorAction Stop
                $cleared++
            }
            catch {
                Write-Warning "Could not delete spool file $($job.Name): $($_.Exception.Message)"
            }
        }

        Start-Service -Name Spooler -ErrorAction Stop
        $statusAfter = (Get-Service -Name Spooler).Status

        [pscustomobject]@{
            PSTypeName      = 'Bosun.SpoolerResetResult'
            ComputerName    = $env:COMPUTERNAME
            StatusBefore    = $statusBefore
            StuckJobsFound  = $stuckJobs.Count
            JobFilesCleared = $cleared
            StatusAfter     = $statusAfter
            Success         = ($statusAfter -eq 'Running')
        }
    }
}
