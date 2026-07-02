#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot '..\Bosun\Bosun.psd1'
    Import-Module $script:manifestPath -Force
}

Describe 'Bosun module' {

    It 'has a valid manifest' {
        { Test-ModuleManifest -Path $script:manifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'imports without errors' {
        Get-Module Bosun | Should -Not -BeNullOrEmpty
    }

    It 'exports every function listed in the manifest' {
        $manifest = Import-PowerShellDataFile -Path $script:manifestPath
        $exported = (Get-Module Bosun).ExportedFunctions.Keys
        foreach ($function in $manifest.FunctionsToExport) {
            $exported | Should -Contain $function
        }
    }

    It 'does not export private helpers' {
        $exported = (Get-Module Bosun).ExportedFunctions.Keys
        $privateFiles = Get-ChildItem (Join-Path $PSScriptRoot '..\Bosun\Private') -Filter '*.ps1'
        foreach ($file in $privateFiles) {
            $exported | Should -Not -Contain $file.BaseName
        }
    }
}

Describe 'Public function conventions' {

    BeforeDiscovery {
        $publicFunctions = (Get-ChildItem (Join-Path $PSScriptRoot '..\Bosun\Public') -Filter '*.ps1').BaseName
    }

    Context '<_>' -ForEach $publicFunctions {

        BeforeAll {
            $script:functionName = $_
            $script:help = Get-Help $script:functionName -Full
        }

        It 'uses an approved verb' {
            $verb = ($script:functionName -split '-')[0]
            (Get-Verb).Verb | Should -Contain $verb
        }

        It 'has a synopsis' {
            $script:help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'has a description' {
            $script:help.Description | Should -Not -BeNullOrEmpty
        }

        It 'has at least two examples' {
            @($script:help.Examples.Example).Count | Should -BeGreaterOrEqual 2
        }
    }
}
