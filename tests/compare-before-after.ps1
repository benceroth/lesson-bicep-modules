# Measures the flat template (01) against the module refactor (02) and the parts bin (03),
# and writes evidence/refactor-comparison.md. Offline: it only compiles files in this repo.
# Everything in the "Measured" table is counted from the files; the "Projection" table is arithmetic
# on those counts, not a measurement. Add -Check to fail if the committed report is stale.
param([switch] $Check)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/lib.ps1"

# Non-blank lines that are not comment-only.
function Get-CodeLines([string[]] $Paths) {
    $n = 0
    foreach ($p in $Paths) {
        $n += @(Get-Content (Get-RepoPath $p) | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('//') }).Count
    }
    $n
}

$policyPattern = 'supportsHttpsTrafficOnly:|minimumTlsVersion:|allowBlobPublicAccess:|deleteRetentionPolicy:|days:'
function Get-PolicyLines([string[]] $Paths) {
    $n = 0
    foreach ($p in $Paths) { $n += @(Select-String -Path (Get-RepoPath $p) -Pattern $policyPattern).Count }
    $n
}

function Measure-Set([string] $Name, [string] $Main, [string[]] $Files) {
    $built = Invoke-BicepBuild (Get-RepoPath $Main)
    if (-not $built.Ok) { throw "$Main does not compile:`n$($built.Diagnostics)" }
    $mod = Get-ModuleDeployments $built.Template | Select-Object -First 1
    $contract = $null
    if ($mod) { $contract = Get-Contract $mod.properties.template } else { $contract = Get-Contract $built.Template }
    [pscustomobject]@{
        Name          = $Name
        Files         = $Files.Count
        CodeLines     = Get-CodeLines $Files
        Resources     = @(Get-AllResources $built.Template | Where-Object { $_.type -ne 'Microsoft.Resources/deployments' }).Count
        CallerParams  = (Get-Contract $built.Template).Parameters.Count
        ModuleParams  = if ($mod) { $contract.Parameters.Count } else { 0 }
        ModuleOutputs = if ($mod) { $contract.Outputs.Count } else { 0 }
        Constrained   = if ($mod) { @($contract.Parameters.Values | Where-Object { $_.Allowed.Count -gt 0 }).Count } else { 0 }
        PolicyLines   = Get-PolicyLines $Files
    }
}

$flat = Measure-Set '01 flat' '01-flat-baseline/main.bicep' @('01-flat-baseline/main.bicep')
$ext = Measure-Set '02 module' '02-extracted/main.bicep' @('02-extracted/main.bicep', '02-extracted/modules/storage.bicep')
$bin = Measure-Set '03 parts bin' '03-anti-pattern-parts-bin/main.bicep' @('03-anti-pattern-parts-bin/main.bicep', '03-anti-pattern-parts-bin/modules/storage-everything.bicep')

$bin.PolicyLines = '-'
$ver = (Get-Content (Get-RepoPath '.bicep-version') -Raw).Trim()
$rows = foreach ($s in $flat, $ext, $bin) {
    "| $($s.Name) | $($s.Files) | $($s.CodeLines) | $($s.Resources) | $($s.CallerParams) | $($s.ModuleParams) | $($s.Constrained) | $($s.ModuleOutputs) | $($s.PolicyLines) |"
}

# The flat file deploys one environment per run; a team that copies it per environment repeats its policy lines.
$envs = 3
$flatCopies = $flat.PolicyLines * $envs
$moduleCopies = $ext.PolicyLines

$report = @"
# Refactor comparison: flat vs module

Measured on the files in this repo (Bicep $ver). Offline; nothing is deployed.
Regenerate with ``./tests/compare-before-after.ps1`` (``-Check`` fails if this file is stale).

## Measured

| Version | Files | Code lines | Deployed resources | Parent params | Module params | Module params with @allowed | Module outputs | Policy lines |
|---|---|---|---|---|---|---|---|---|
$($rows -join "`n")

- *Code lines*: non-blank lines that are not comment-only, across the files listed for that version.
- *Deployed resources*: resources in the compiled template, including those inside the module; 01 and 02 deploy the same ones.
- *Policy lines*: lines setting HTTPS-only, TLS, public blob access or retention. Not counted for 03, where they are parameters with defaults.
- Rows 01 and 02 deploy identical resources (see ``./tests/what-if-equivalence.ps1``). The module is not shorter; its value is the narrower surface callers see: $($ext.ModuleParams) module parameters instead of $($bin.ModuleParams).

## Projection (arithmetic on the numbers above, not a measurement)

| Scenario | Policy lines to keep in sync |
|---|---|
| Flat template copied for $envs environments | $flatCopies ($($flat.PolicyLines) x $envs) |
| One shared module used by $envs environments | $moduleCopies |

The $envs-copy row assumes a team copies the flat file per environment. The repo does not contain such copies.
"@

$out = Get-RepoPath 'evidence/refactor-comparison.md'
$report = ($report -replace "`r`n", "`n").TrimEnd() + "`n"
if ($Check) {
    $current = (Get-Content $out -Raw) -replace "`r`n", "`n"
    if ($current -ne $report) { Write-Host 'evidence/refactor-comparison.md is stale. Run ./tests/compare-before-after.ps1'; exit 1 }
    Write-Host 'evidence/refactor-comparison.md is up to date'
    exit 0
}
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
[IO.File]::WriteAllText($out, $report)
Write-Host $report
