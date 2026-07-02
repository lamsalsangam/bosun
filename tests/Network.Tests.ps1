#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\Bosun\Bosun.psd1') -Force
}

Describe 'Clear-BosunDns' {

    It 'flushes the cache and reports entries cleared' {
        $result = Clear-BosunDns -Confirm:$false
        $result.PSObject.TypeNames | Should -Contain 'Bosun.DnsFlushResult'
        $result.Flushed | Should -BeTrue
        $result.EntriesBefore | Should -BeGreaterOrEqual 0
    }

    It 'does nothing with -WhatIf' {
        Mock -ModuleName Bosun Clear-DnsClientCache {}
        Clear-BosunDns -WhatIf | Should -BeNullOrEmpty
        Should -Invoke -ModuleName Bosun Clear-DnsClientCache -Times 0
    }
}

Describe 'Reset-BosunNetwork' {

    Context 'without admin rights' {

        It 'refuses with a clear error' {
            Mock -ModuleName Bosun Test-BosunElevation { $false }
            { Reset-BosunNetwork -Confirm:$false -ErrorAction Stop } | Should -Throw '*elevated*'
        }
    }

    Context 'elevated (mocked network stack)' {

        BeforeAll {
            Mock -ModuleName Bosun Test-BosunElevation { $true }
            Mock -ModuleName Bosun Get-NetAdapter {
                [pscustomobject]@{ Name = 'Ethernet'; InterfaceDescription = 'Test NIC'; Status = 'Up'; ifIndex = 7 }
            }
            Mock -ModuleName Bosun Get-NetIPAddress {
                [pscustomobject]@{ IPAddress = '192.168.1.50' }
            }
            Mock -ModuleName Bosun Get-CimInstance {
                [pscustomobject]@{ DHCPEnabled = $true; InterfaceIndex = 7 }
            }
            Mock -ModuleName Bosun Invoke-BosunDhcpRenew {}
            Mock -ModuleName Bosun Clear-DnsClientCache {}
            Mock -ModuleName Bosun Restart-NetAdapter {}
        }

        It 'flushes DNS and renews DHCP on matching adapters' {
            $result = Reset-BosunNetwork -Confirm:$false -WarningAction SilentlyContinue

            Should -Invoke -ModuleName Bosun Clear-DnsClientCache -Times 1
            Should -Invoke -ModuleName Bosun Invoke-BosunDhcpRenew -Times 1 -Exactly
            Should -Invoke -ModuleName Bosun Restart-NetAdapter -Times 0

            $result.Adapters[0].Adapter | Should -Be 'Ethernet'
            $result.Adapters[0].DhcpRenewed | Should -BeTrue
            $result.Adapters[0].Restarted | Should -BeFalse
        }

        It 'restarts adapters only with -RestartAdapters' {
            $result = Reset-BosunNetwork -RestartAdapters -Confirm:$false -WarningAction SilentlyContinue
            Should -Invoke -ModuleName Bosun Restart-NetAdapter -Times 1
            $result.Adapters[0].Restarted | Should -BeTrue
        }

        It 'skips DHCP renew on static adapters and says so' {
            Mock -ModuleName Bosun Get-CimInstance {
                [pscustomobject]@{ DHCPEnabled = $false; InterfaceIndex = 7 }
            }
            $result = Reset-BosunNetwork -Confirm:$false -WarningAction SilentlyContinue
            $result.Adapters[0].DhcpRenewed | Should -BeFalse
            $result.Adapters[0].Note | Should -Match 'Static'
        }

        It 'makes no changes with -WhatIf' {
            Reset-BosunNetwork -WhatIf
            Should -Invoke -ModuleName Bosun Clear-DnsClientCache -Times 0
            Should -Invoke -ModuleName Bosun Invoke-BosunDhcpRenew -Times 0
        }
    }

    Context 'command design' {

        It 'supports ShouldProcess with high confirm impact' {
            $command = Get-Command Reset-BosunNetwork
            $command.Parameters.Keys | Should -Contain 'WhatIf'
            $metadata = [System.Management.Automation.CommandMetadata]::new($command)
            $metadata.ConfirmImpact | Should -Be 'High'
        }
    }
}
