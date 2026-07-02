#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\Bosun\Bosun.psd1') -Force
    $script:testPassword = ConvertTo-SecureString 'Placeholder-Test-Pw!' -AsPlainText -Force
}

Describe 'New-BosunUser' {

    Context 'without admin rights' {

        It 'refuses with a clear error and creates nothing' {
            Mock -ModuleName Bosun Test-BosunElevation { $false }
            Mock -ModuleName Bosun New-LocalUser {}
            { New-BosunUser -Name testuser -Password $script:testPassword -Confirm:$false -ErrorAction Stop } |
                Should -Throw '*elevated*'
            Should -Invoke -ModuleName Bosun New-LocalUser -Times 0
        }
    }

    Context 'elevated (mocked LocalAccounts)' {

        BeforeAll {
            Mock -ModuleName Bosun Test-BosunElevation { $true }
            Mock -ModuleName Bosun Get-LocalUser {}
            Mock -ModuleName Bosun New-LocalUser { [pscustomobject]@{ Name = $Name } }
            Mock -ModuleName Bosun Add-LocalGroupMember {}
            Mock -ModuleName Bosun Set-BosunPasswordChangeAtLogon {}
        }

        It 'creates the account and adds it to Users by default' {
            $result = New-BosunUser -Name jdoe -Password $script:testPassword -FullName 'Jane Doe' -Confirm:$false

            Should -Invoke -ModuleName Bosun New-LocalUser -Times 1 -Exactly
            Should -Invoke -ModuleName Bosun Add-LocalGroupMember -Times 1 -Exactly -ParameterFilter { "$Group" -eq 'Users' }

            $result.Name | Should -Be 'jdoe'
            $result.Groups | Should -Be @('Users')
            $result.Created | Should -BeTrue
        }

        It 'adds the account to every requested group' {
            $result = New-BosunUser -Name jdoe -Password $script:testPassword -Group 'Users', 'Remote Desktop Users' -Confirm:$false
            Should -Invoke -ModuleName Bosun Add-LocalGroupMember -Times 2 -Exactly
            $result.Groups.Count | Should -Be 2
        }

        It 'flags password change at first logon only with -RequirePasswordChange' {
            $null = New-BosunUser -Name jdoe -Password $script:testPassword -Confirm:$false
            Should -Invoke -ModuleName Bosun Set-BosunPasswordChangeAtLogon -Times 0

            $null = New-BosunUser -Name jdoe -Password $script:testPassword -RequirePasswordChange -Confirm:$false
            Should -Invoke -ModuleName Bosun Set-BosunPasswordChangeAtLogon -Times 1
        }

        It 'refuses to create an account that already exists' {
            Mock -ModuleName Bosun Get-LocalUser { [pscustomobject]@{ Name = 'jdoe'; Enabled = $true } }
            { New-BosunUser -Name jdoe -Password $script:testPassword -Confirm:$false -ErrorAction Stop } |
                Should -Throw '*already exists*'
            Should -Invoke -ModuleName Bosun New-LocalUser -Times 0
        }

        It 'creates nothing with -WhatIf' {
            New-BosunUser -Name jdoe -Password $script:testPassword -WhatIf
            Should -Invoke -ModuleName Bosun New-LocalUser -Times 0
            Should -Invoke -ModuleName Bosun Add-LocalGroupMember -Times 0
        }

        It 'rejects names longer than 20 characters (SAM limit)' {
            { New-BosunUser -Name 'a-very-long-user-name-over-20' -Password $script:testPassword } | Should -Throw
        }
    }
}

Describe 'Disable-BosunUser' {

    Context 'without admin rights' {

        It 'refuses with a clear error' {
            Mock -ModuleName Bosun Test-BosunElevation { $false }
            { Disable-BosunUser -Name jdoe -Confirm:$false -ErrorAction Stop } | Should -Throw '*elevated*'
        }
    }

    Context 'elevated (mocked LocalAccounts)' {

        BeforeAll {
            Mock -ModuleName Bosun Test-BosunElevation { $true }
            Mock -ModuleName Bosun Get-LocalUser { [pscustomobject]@{ Name = 'jdoe'; Enabled = $true } }
            Mock -ModuleName Bosun Disable-LocalUser {}
            Mock -ModuleName Bosun Set-LocalUser {}
        }

        It 'disables the account and reports the previous state' {
            $result = Disable-BosunUser -Name jdoe -Confirm:$false

            Should -Invoke -ModuleName Bosun Disable-LocalUser -Times 1 -Exactly
            $result.WasEnabled | Should -BeTrue
            $result.Enabled | Should -BeFalse
            $result.Disabled | Should -BeTrue
        }

        It 'stamps the reason into the description with -Reason' {
            $null = Disable-BosunUser -Name jdoe -Reason 'left company - ticket #4302' -Confirm:$false
            Should -Invoke -ModuleName Bosun Set-LocalUser -Times 1 -ParameterFilter {
                $Description -match 'Disabled \d{4}-\d{2}-\d{2}: left company - ticket #4302'
            }
        }

        It 'does not touch the description without -Reason' {
            $null = Disable-BosunUser -Name jdoe -Confirm:$false
            Should -Invoke -ModuleName Bosun Set-LocalUser -Times 0
        }

        It 'errors clearly when the user does not exist' {
            Mock -ModuleName Bosun Get-LocalUser {}
            { Disable-BosunUser -Name ghost -Confirm:$false -ErrorAction Stop } | Should -Throw '*was found*'
        }

        It 'changes nothing with -WhatIf' {
            Disable-BosunUser -Name jdoe -WhatIf
            Should -Invoke -ModuleName Bosun Disable-LocalUser -Times 0
        }
    }
}
