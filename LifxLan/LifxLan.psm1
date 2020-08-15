#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

# Get the public and private elements (wrap as arrays for consistency)
$PrivateTypes = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath "Private\Types.ps1") -ErrorAction SilentlyContinue)
$PublicTypes = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath "Public\Types.ps1") -ErrorAction SilentlyContinue)
$PrivateModules = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath "Private\*-*.ps1") -ErrorAction SilentlyContinue)
$PublicModules = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath "Public\*-*.ps1") -ErrorAction SilentlyContinue)

# Dot source each of the element scripts into current scope
# Process in order: enums/classes/private/public to (hopefully) ensure dependecies are met
# Public types (enums/classes) are imported through ScriptsToProcess in the psd1, and are loaded before the rest of the module
foreach ($ImportModule in @($PrivateTypes + $PublicTypes + $PrivateModules + $PublicModules)) {
    try {
        Write-Verbose -Message "Loading $($ImportModule.FullName)"
        . $ImportModule.FullName
    } catch {
        Write-Error -Message "Failed to import function $($ImportModule.FullName): $PSItem"
    }
}

# Export all the public cmdlets
Export-ModuleMember -Function $PublicModules.BaseName