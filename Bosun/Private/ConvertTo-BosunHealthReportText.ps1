function ConvertTo-BosunHealthReportText {
    <#
    .SYNOPSIS
        Renders a Bosun.HealthReport object as a plain-text report suitable
        for pasting into a ticket or escalation email.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject]$Report
    )

    process {
        $sb = New-Object System.Text.StringBuilder
        $rule = '=' * 70

        [void]$sb.AppendLine($rule)
        [void]$sb.AppendLine("SYSTEM HEALTH REPORT - $($Report.ComputerName)")
        [void]$sb.AppendLine("Generated: $($Report.GeneratedAt)  (elevated: $($Report.IsElevated))")
        [void]$sb.AppendLine($rule)

        $os = $Report.OperatingSystem
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('OPERATING SYSTEM')
        [void]$sb.AppendLine("  $($os.Caption) (build $($os.Build))")
        [void]$sb.AppendLine("  Last boot: $($os.LastBoot)   Uptime: $($os.UptimeText)")

        $hw = $Report.Hardware
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('HARDWARE')
        [void]$sb.AppendLine("  $($hw.Manufacturer) $($hw.Model), $($hw.LogicalProcessors) logical processors")

        $mem = $Report.Memory
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('MEMORY')
        [void]$sb.AppendLine(("  {0:N1} GB total, {1:N1} GB free ({2}% used)" -f $mem.TotalGB, $mem.FreeGB, $mem.UsedPercent))

        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('DISKS')
        foreach ($disk in $Report.Disks) {
            $flag = ''
            if ($disk.LowSpace) { $flag = '  << LOW SPACE' }
            [void]$sb.AppendLine(("  {0} {1,-12} {2,8:N1} GB total {3,8:N1} GB free ({4}% free){5}" -f `
                $disk.Drive, "[$($disk.Label)]", $disk.TotalGB, $disk.FreeGB, $disk.FreePercent, $flag))
        }

        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("TOP PROCESSES (by memory)")
        foreach ($proc in $Report.TopProcesses) {
            [void]$sb.AppendLine(("  {0,-28} PID {1,-7} {2,8:N0} MB" -f $proc.Name, $proc.Id, $proc.MemoryMB))
        }

        $reboot = $Report.PendingReboot
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('PENDING REBOOT')
        if ($reboot.IsPending) {
            foreach ($reason in $reboot.Reasons) {
                [void]$sb.AppendLine("  YES - $reason")
            }
        }
        else {
            [void]$sb.AppendLine('  No')
        }

        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("RECENT ERRORS (System + Application, last $($Report.EventHours)h)")
        if ($Report.RecentErrors.Count -eq 0) {
            [void]$sb.AppendLine('  None found')
        }
        else {
            foreach ($errorEvent in $Report.RecentErrors) {
                [void]$sb.AppendLine(("  {0:yyyy-MM-dd HH:mm}  {1,-11}  {2}/{3}" -f $errorEvent.TimeCreated, $errorEvent.Log, $errorEvent.Provider, $errorEvent.Id))
                [void]$sb.AppendLine("      $($errorEvent.Message)")
            }
        }

        if ($Report.Notes.Count -gt 0) {
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('NOTES')
            foreach ($note in $Report.Notes) {
                [void]$sb.AppendLine("  - $note")
            }
        }

        [void]$sb.AppendLine($rule)
        $sb.ToString()
    }
}
