# Builds and lints every Bicep file that must compile offline. Fails on any error or lint warning.
# 04-registry/consumer is skipped: restoring br/ modules needs a registry (see 04-registry/README.md).
# tests/fixtures contains files that are EXPECTED to fail; contract-tests.ps1 covers them.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/lib.ps1"

$files = @(
    '01-flat-baseline/main.bicep',
    '02-extracted/main.bicep',
    '02-extracted/modules/storage.bicep',
    '03-anti-pattern-parts-bin/main.bicep',
    '03-anti-pattern-parts-bin/modules/storage-everything.bicep',
    '05-breaking-change/storage-v1.bicep',
    '05-breaking-change/storage-v2.bicep',
    '05-breaking-change/consumer-v1.bicep',
    '05-breaking-change/consumer-v2.bicep'
)
$paramFiles = Get-ChildItem (Get-RepoPath '02-extracted/params') -Filter *.bicepparam | ForEach-Object { $_.FullName }

Write-Host '== build + lint'
foreach ($f in $files) {
    $path = Get-RepoPath $f
    $build = Invoke-BicepBuild $path
    Assert-That "build  $f" $build.Ok $build.Diagnostics

    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $lint = @(& az bicep lint --file $path 2>&1 | ForEach-Object { "$_" })
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    $findings = @($lint | Where-Object { $_ -match '(Warning|Error) [\w-]+:' -or $_ -match '^ERROR' })
    Assert-That "lint   $f" ($code -eq 0 -and $findings.Count -eq 0) ($findings -join "`n")
}
foreach ($f in $paramFiles) {
    $r = Invoke-BicepBuild $f -Params
    Assert-That "params $([IO.Path]::GetFileName($f))" $r.Ok $r.Diagnostics
}

Write-Host '== config files parse'
foreach ($c in 'bicepconfig.json', '04-registry/bicepconfig.json') {
    $ok = $true
    try { Get-Content (Get-RepoPath $c) -Raw | ConvertFrom-Json | Out-Null } catch { $ok = $false }
    Assert-That "valid JSON $c" $ok
}
Assert-That '04-registry/consumer pins an exact version' ((Get-Content (Get-RepoPath '04-registry/consumer/main.bicep') -Raw) -match "br/northstar:storage:\d+\.\d+\.\d+'")

Write-Host '== break-it scenarios and committed reports'
$prev = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$null = & pwsh -NoProfile -File (Get-RepoPath 'break-it/run.ps1') 2>&1
Assert-That 'break-it/run.ps1 observes every expected failure' ($LASTEXITCODE -eq 0)
foreach ($s in 'compare-before-after.ps1', 'blast-radius.ps1') {
    $null = & pwsh -NoProfile -File (Join-Path $PSScriptRoot $s) -Check 2>&1
    Assert-That "evidence is current ($s -Check)" ($LASTEXITCODE -eq 0)
}
$ErrorActionPreference = $prev

exit (Write-TestSummary)
