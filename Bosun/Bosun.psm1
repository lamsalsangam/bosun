# Bosun module root: dot-source all function files and export the public ones.
# Public/  - one exported function per file (filename matches function name)
# Private/ - internal helpers, not exported

$public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue)
$private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($file in @($private + $public)) {
    try {
        . $file.FullName
    }
    catch {
        Write-Error "Failed to load $($file.FullName): $_"
    }
}

Export-ModuleMember -Function $public.BaseName
