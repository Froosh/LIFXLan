[CmdletBinding()]

Param (

)

Import-Module -Name (Join-Path -Path (Split-Path -Parent $PSCommandPath) -ChildPath ./LifxLan/LifxLan.psm1) -Verbose

Find-Device -All -Verbose
