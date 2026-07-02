@{
    RootModule        = 'Bosun.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'aa4b54c3-71a2-4a29-8667-52710a6abdee'
    Author            = 'Sangam Lamsal'
    Copyright         = '(c) Sangam Lamsal. All rights reserved.'
    Description       = 'IT support script toolkit: system health reports, one-click fixes, and provisioning helpers for help-desk work.'
    PowerShellVersion = '5.1'

    # Explicit export list (updated as commands land) - keeps discovery fast
    # and makes the public surface obvious.
    FunctionsToExport = @(
        'Clear-BosunDns'
        'Get-BosunHealthReport'
        'Get-BosunSoftwareInventory'
        'Reset-BosunNetwork'
        'Reset-BosunPrintSpooler'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('IT-Support', 'HelpDesk', 'Diagnostics', 'Windows', 'SysAdmin')
            LicenseUri   = 'https://github.com/lamsalsangam/bosun/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/lamsalsangam/bosun'
            ReleaseNotes = 'v0.1.0 - initial release: Get-BosunHealthReport'
        }
    }
}
