# Opt-in: publishes 02-extracted/modules/storage.bicep to a private Azure Container Registry.
# Requires: az login, an existing ACR, and push permission (AcrPush role).
# Usage: ./publish.ps1 -RegistryName <acr-name> -Version 1.0.0 [-WhatIf]
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $RegistryName,
    [Parameter(Mandatory)] [ValidatePattern('^\d+\.\d+\.\d+$')] [string] $Version,
    [string] $ModulePath = 'bicep/modules/storage'
)
$ErrorActionPreference = 'Stop'

$file = Join-Path $PSScriptRoot '..\02-extracted\modules\storage.bicep'
$target = "br:$RegistryName.azurecr.io/${ModulePath}:$Version"

az bicep build --file $file --stdout | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Module does not compile; refusing to publish.' }

if ($PSCmdlet.ShouldProcess($target, 'az bicep publish')) {
    # Tags in a registry are mutable by default; enable tag immutability on the ACR repository if you can.
    az bicep publish --file $file --target $target
    if ($LASTEXITCODE -ne 0) { throw 'Publish failed.' }
    Write-Host "Published $target"
}
else {
    Write-Host "Would publish $file -> $target"
}
