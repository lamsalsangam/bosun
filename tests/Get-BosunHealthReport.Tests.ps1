#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\Bosun\Bosun.psd1') -Force

    # One real collection shared across tests (the queries take a few seconds).
    $script:report = Get-BosunHealthReport
}

Describe 'Get-BosunHealthReport' {

    Context 'object output' {

        It 'returns a Bosun.HealthReport object' {
            $script:report.PSObject.TypeNames | Should -Contain 'Bosun.HealthReport'
        }

        It 'has all report sections' -ForEach @(
            'ComputerName', 'GeneratedAt', 'IsElevated', 'OperatingSystem',
            'Hardware', 'Memory', 'Disks', 'TopProcesses', 'PendingReboot',
            'RecentErrors', 'Notes'
        ) {
            $script:report.PSObject.Properties.Name | Should -Contain $_
        }

        It 'reports the local computer name' {
            $script:report.ComputerName | Should -Be $env:COMPUTERNAME
        }

        It 'reports plausible memory numbers' {
            $script:report.Memory.TotalGB | Should -BeGreaterThan 0
            $script:report.Memory.FreeGB | Should -BeLessOrEqual $script:report.Memory.TotalGB
            $script:report.Memory.UsedPercent | Should -BeIn (0..100)
        }

        It 'includes at least one fixed disk with plausible numbers' {
            @($script:report.Disks).Count | Should -BeGreaterThan 0
            foreach ($disk in $script:report.Disks) {
                $disk.FreeGB | Should -BeLessOrEqual $disk.TotalGB
                $disk.FreePercent | Should -BeIn (0..100)
            }
        }

        It 'honors -TopProcessCount' {
            $small = Get-BosunHealthReport -TopProcessCount 3
            @($small.TopProcesses).Count | Should -Be 3
        }

        It 'reports pending-reboot status as a boolean' {
            $script:report.PendingReboot.IsPending | Should -BeOfType [bool]
        }
    }

    Context 'text output' {

        BeforeAll {
            $script:text = Get-BosunHealthReport -AsText
        }

        It 'returns a single string with -AsText' {
            $script:text | Should -BeOfType [string]
        }

        It 'contains the report sections' -ForEach @(
            'SYSTEM HEALTH REPORT', 'OPERATING SYSTEM', 'MEMORY', 'DISKS',
            'TOP PROCESSES', 'PENDING REBOOT', 'RECENT ERRORS'
        ) {
            $script:text | Should -Match ([regex]::Escape($_))
        }
    }

    Context 'file export' {

        It 'writes the text report to -Path and still returns the object' {
            $exportPath = Join-Path $TestDrive 'health.txt'
            $result = Get-BosunHealthReport -Path $exportPath
            Test-Path $exportPath | Should -BeTrue
            (Get-Content $exportPath -Raw) | Should -Match 'SYSTEM HEALTH REPORT'
            $result.PSObject.TypeNames | Should -Contain 'Bosun.HealthReport'
        }
    }

    Context 'parameter validation' {

        It 'rejects out-of-range -TopProcessCount' {
            { Get-BosunHealthReport -TopProcessCount 0 } | Should -Throw
        }

        It 'rejects out-of-range -EventHours' {
            { Get-BosunHealthReport -EventHours 0 } | Should -Throw
        }
    }
}

Describe 'Private helpers' {

    It 'Test-BosunPendingReboot returns IsPending plus matching reasons' {
        InModuleScope Bosun {
            $result = Test-BosunPendingReboot
            $result.IsPending | Should -BeOfType [bool]
            if ($result.IsPending) {
                @($result.Reasons).Count | Should -BeGreaterThan 0
            }
            else {
                @($result.Reasons).Count | Should -Be 0
            }
        }
    }

    It 'ConvertTo-BosunHealthReportText renders a report passed from outside the module' {
        $text = InModuleScope Bosun -Parameters @{ report = $script:report } {
            param($report)
            ConvertTo-BosunHealthReportText -Report $report
        }
        $text | Should -Match 'SYSTEM HEALTH REPORT'
    }
}
