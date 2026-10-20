# Compares the public contract (parameters + outputs) of two Bicep modules offline and
# reports the semver bump the change requires. See docs/contract-template.md.
# Usage: ./contract-diff.ps1 -Old ../05-breaking-change/storage-v1.bicep -New ../05-breaking-change/storage-v2.bicep
param(
    [Parameter(Mandatory)] [string] $Old,
    [Parameter(Mandatory)] [string] $New
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/lib.ps1"

$a = Invoke-BicepBuild (Resolve-Path $Old).Path
$b = Invoke-BicepBuild (Resolve-Path $New).Path
if (-not $a.Ok) { throw "Old module does not compile:`n$($a.Diagnostics)" }
if (-not $b.Ok) { throw "New module does not compile:`n$($b.Diagnostics)" }

$diff = Compare-Contract (Get-Contract $a.Template) (Get-Contract $b.Template)
if ($diff.Changes.Count -eq 0) { Write-Host 'No contract changes.' }
$diff.Changes | ForEach-Object { Write-Host ("[{0}] {1}" -f $_.Level, $_.Text) }
Write-Host "Required version bump: $($diff.RequiredBump)"
