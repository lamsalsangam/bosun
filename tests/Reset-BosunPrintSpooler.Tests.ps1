#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\Bosun\Bosun.psd1') -Force
}

Describe 'Reset-BosunPrintSpooler' {

    Context 'without admin rights' {

        BeforeAll {
            Mock -ModuleName Bosun Test-BosunElevation { $false }
        }

        It 'refuses with a clear error and changes nothing' {
            Mock -ModuleName Bosun Stop-Service {}
            { Reset-BosunPrintSpooler -Force -ErrorAction Stop } | Should -Throw '*elevated*'
            Should -Invoke -ModuleName Bosun Stop-Service -Times 0
        }
    }

    Context 'elevated (mocked service and spool directory)' {

        BeforeAll {
            Mock -ModuleName Bosun Test-BosunElevation { $true }
            Mock -ModuleName Bosun Get-Service { [pscustomobject]@{ Name = 'Spooler'; Status = 'Running' } }
            Mock -ModuleName Bosun Get-ChildItem {
                [pscustomobject]@{ Name = '00001.SPL'; FullName = 'C:\spool\00001.SPL' }
                [pscustomobject]@{ Name = '00001.SHD'; FullName = 'C:\spool\00001.SHD' }
            }
            Mock -ModuleName Bosun Stop-Service {}
            Mock -ModuleName Bosun Start-Service {}
            Mock -ModuleName Bosun Remove-Item {}
        }

        It 'stops the service, clears stuck jobs, and restarts' {
            $result = Reset-BosunPrintSpooler -Force

            Should -Invoke -ModuleName Bosun Stop-Service -Times 1 -Exactly
            Should -Invoke -ModuleName Bosun Remove-Item -Times 2 -Exactly
            Should -Invoke -ModuleName Bosun Start-Service -Times 1 -Exactly

            $result.StuckJobsFound | Should -Be 2
            $result.JobFilesCleared | Should -Be 2
            $result.Success | Should -BeTrue
        }

        It 'makes no changes with -WhatIf' {
            Reset-BosunPrintSpooler -WhatIf

            Should -Invoke -ModuleName Bosun Stop-Service -Times 0
            Should -Invoke -ModuleName Bosun Remove-Item -Times 0
            Should -Invoke -ModuleName Bosun Start-Service -Times 0
        }

        It 'keeps counting when a spool file cannot be deleted' {
            Mock -ModuleName Bosun Remove-Item { throw 'locked' } -ParameterFilter { $LiteralPath -like '*.SPL' }

            $result = Reset-BosunPrintSpooler -Force -WarningAction SilentlyContinue
            $result.StuckJobsFound | Should -Be 2
            $result.JobFilesCleared | Should -Be 1
        }
    }

    Context 'command design' {

        It 'supports ShouldProcess (-WhatIf / -Confirm)' {
            $command = Get-Command Reset-BosunPrintSpooler
            $command.Parameters.Keys | Should -Contain 'WhatIf'
            $command.Parameters.Keys | Should -Contain 'Confirm'
        }
    }
}
