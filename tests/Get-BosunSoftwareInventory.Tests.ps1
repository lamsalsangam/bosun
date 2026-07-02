#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\Bosun\Bosun.psd1') -Force
    $script:inventory = @(Get-BosunSoftwareInventory)
}

Describe 'Get-BosunSoftwareInventory' {

    It 'finds installed software' {
        $script:inventory.Count | Should -BeGreaterThan 0
    }

    It 'returns Bosun.SoftwareEntry objects with the expected properties' {
        $entry = $script:inventory[0]
        $entry.PSObject.TypeNames | Should -Contain 'Bosun.SoftwareEntry'
        foreach ($property in 'Name', 'Version', 'Publisher', 'InstallDate', 'Scope', 'Architecture') {
            $entry.PSObject.Properties.Name | Should -Contain $property
        }
    }

    It 'every entry has a name' {
        $script:inventory | Where-Object { -not $_.Name } | Should -BeNullOrEmpty
    }

    It 'is sorted by name' {
        $names = $script:inventory.Name
        $sorted = $names | Sort-Object
        # Compare as joined strings to keep the failure output readable
        ($names -join '|') | Should -Be ($sorted -join '|')
    }

    It 'filters by wildcard -Name' {
        $sample = $script:inventory[0].Name
        $filtered = @(Get-BosunSoftwareInventory -Name $sample)
        $filtered.Count | Should -BeGreaterThan 0
        $filtered | Where-Object { $_.Name -ne $sample } | Should -BeNullOrEmpty
    }

    It 'excludes system components by default' {
        # With the switch the list can only grow
        $withSystem = @(Get-BosunSoftwareInventory -IncludeSystemComponents)
        $withSystem.Count | Should -BeGreaterOrEqual $script:inventory.Count
    }

    It 'exports valid CSV with -Path' {
        $csvPath = Join-Path $TestDrive 'inventory.csv'
        $null = Get-BosunSoftwareInventory -Path $csvPath
        Test-Path $csvPath | Should -BeTrue

        $csv = Import-Csv $csvPath
        @($csv).Count | Should -Be $script:inventory.Count
        $csv[0].PSObject.Properties.Name | Should -Contain 'Name'
        $csv[0].PSObject.Properties.Name | Should -Contain 'Version'
    }
}
