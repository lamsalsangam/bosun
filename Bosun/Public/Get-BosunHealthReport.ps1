function Get-BosunHealthReport {
    <#
    .SYNOPSIS
        Collects a one-click system health snapshot: OS and uptime, disk
        space, memory, top processes, pending-reboot status, and recent
        error events.

    .DESCRIPTION
        Gathers the checks a help-desk tech runs first on a "my computer is
        slow / broken" ticket and returns them as a single structured
        object. Use -AsText to get a formatted plain-text report instead,
        ready to paste into a ticket, or -Path to save that text report to
        a file for escalation.

        Runs without administrator rights; anything it cannot read in a
        non-elevated session is skipped and listed in the report's Notes.
        Windows-only (uses CIM and the Windows event log).

    .PARAMETER TopProcessCount
        How many processes to include in the top-memory list. Default 5.

    .PARAMETER EventHours
        How far back to look for critical/error events in the System and
        Application logs. Default 24 hours.

    .PARAMETER AsText
        Return the report as formatted text instead of an object.

    .PARAMETER Path
        Also write the text report to this file. The function still returns
        its normal output (object, or text with -AsText).

    .EXAMPLE
        Get-BosunHealthReport

        Quick triage at the start of a ticket: returns the health object;
        drill in with e.g. (Get-BosunHealthReport).Disks.

    .EXAMPLE
        Get-BosunHealthReport -AsText

        Formatted text report for pasting straight into the ticket notes.

    .EXAMPLE
        Get-BosunHealthReport -EventHours 72 -Path "$env:TEMP\health-$env:COMPUTERNAME.txt"

        After a weekend outage: check three days of error events and save
        the report to a file to attach to the escalation.

    .OUTPUTS
        Bosun.HealthReport (PSCustomObject), or System.String with -AsText.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject], [string])]
    param(
        [ValidateRange(1, 50)]
        [int]$TopProcessCount = 5,

        [ValidateRange(1, 720)]
        [int]$EventHours = 24,

        [switch]$AsText,

        [string]$Path
    )

    if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
        Write-Warning 'Get-BosunHealthReport is Windows-only. On Linux/macOS use bash/bosun-health-report.sh instead.'
        return
    }

    $notes = New-Object System.Collections.Generic.List[string]
    $isElevated = Test-BosunElevation
    if (-not $isElevated) {
        $notes.Add('Session is not elevated; all standard checks still ran (none require admin rights).')
    }

    # --- OS / uptime -----------------------------------------------------
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $uptime = (Get-Date) - $osInfo.LastBootUpTime
    $operatingSystem = [pscustomobject]@{
        Caption    = $osInfo.Caption
        Version    = $osInfo.Version
        Build      = $osInfo.BuildNumber
        LastBoot   = $osInfo.LastBootUpTime
        Uptime     = $uptime
        UptimeText = '{0}d {1}h {2}m' -f [int]$uptime.Days, $uptime.Hours, $uptime.Minutes
    }

    # --- Hardware ---------------------------------------------------------
    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    $hardware = [pscustomobject]@{
        Manufacturer      = $computerSystem.Manufacturer
        Model             = $computerSystem.Model
        LogicalProcessors = $computerSystem.NumberOfLogicalProcessors
    }

    # --- Memory (Win32_OperatingSystem reports KB) -------------------------
    $totalMemGB = $osInfo.TotalVisibleMemorySize / 1MB
    $freeMemGB = $osInfo.FreePhysicalMemory / 1MB
    $memory = [pscustomobject]@{
        TotalGB     = [math]::Round($totalMemGB, 1)
        FreeGB      = [math]::Round($freeMemGB, 1)
        UsedPercent = [math]::Round((($totalMemGB - $freeMemGB) / $totalMemGB) * 100)
    }

    # --- Disks (fixed drives only) -----------------------------------------
    $disks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 3' | ForEach-Object {
            $freePercent = 0
            if ($_.Size -gt 0) { $freePercent = [math]::Round(($_.FreeSpace / $_.Size) * 100) }
            [pscustomobject]@{
                Drive       = $_.DeviceID
                Label       = $_.VolumeName
                TotalGB     = [math]::Round($_.Size / 1GB, 1)
                FreeGB      = [math]::Round($_.FreeSpace / 1GB, 1)
                FreePercent = $freePercent
                LowSpace    = ($freePercent -lt 10)
            }
        })

    # --- Top processes by memory -------------------------------------------
    $topProcesses = @(Get-Process |
            Sort-Object WorkingSet64 -Descending |
            Select-Object -First $TopProcessCount |
            ForEach-Object {
                [pscustomobject]@{
                    Name     = $_.ProcessName
                    Id       = $_.Id
                    MemoryMB = [math]::Round($_.WorkingSet64 / 1MB)
                }
            })

    # --- Pending reboot ------------------------------------------------------
    $pendingReboot = Test-BosunPendingReboot

    # --- Recent critical/error events ---------------------------------------
    $since = (Get-Date).AddHours(-$EventHours)
    $recentErrors = New-Object System.Collections.Generic.List[object]
    foreach ($logName in 'System', 'Application') {
        try {
            $events = Get-WinEvent -FilterHashtable @{ LogName = $logName; Level = 1, 2; StartTime = $since } -MaxEvents 10 -ErrorAction Stop
            foreach ($logEvent in $events) {
                $firstLine = ''
                if ($logEvent.Message) { $firstLine = ($logEvent.Message -split "`r?`n")[0] }
                $recentErrors.Add([pscustomobject]@{
                        TimeCreated = $logEvent.TimeCreated
                        Log         = $logName
                        Provider    = $logEvent.ProviderName
                        Id          = $logEvent.Id
                        Message     = $firstLine
                    })
            }
        }
        catch {
            if ($_.Exception.Message -notmatch 'No events were found') {
                $notes.Add("Could not read the $logName event log: $($_.Exception.Message)")
            }
        }
    }

    $report = [pscustomobject]@{
        PSTypeName      = 'Bosun.HealthReport'
        ComputerName    = $env:COMPUTERNAME
        GeneratedAt     = Get-Date
        IsElevated      = $isElevated
        OperatingSystem = $operatingSystem
        Hardware        = $hardware
        Memory          = $memory
        Disks           = $disks
        TopProcesses    = $topProcesses
        PendingReboot   = $pendingReboot
        EventHours      = $EventHours
        RecentErrors    = @($recentErrors | Sort-Object TimeCreated -Descending)
        Notes           = @($notes)
    }

    if ($Path) {
        ConvertTo-BosunHealthReportText -Report $report | Set-Content -Path $Path -Encoding UTF8
    }

    if ($AsText) {
        ConvertTo-BosunHealthReportText -Report $report
    }
    else {
        $report
    }
}
