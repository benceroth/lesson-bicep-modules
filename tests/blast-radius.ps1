# Contract-breaking-change blast radius for storage v1 -> v2, written to evidence/blast-radius.md.
# Offline. Finds every Bicep caller in this repo that references the OLD module, points a scratch copy
# at the NEW module, compiles it, and reports which callers break and why. Add -Check to fail if the
# committed report is stale. Only callers inside this repo are visible to it; real consumers in other
# repositories are not.
param(
    [string] $Old = '05-breaking-change/storage-v1.bicep',
    [string] $New = '05-breaking-change/storage-v2.bicep',
    [switch] $Check
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/lib.ps1"

$oldName = Split-Path $Old -Leaf
$newName = Split-Path $New -Leaf
$a = Invoke-BicepBuild (Get-RepoPath $Old)
$b = Invoke-BicepBuild (Get-RepoPath $New)
if (-not ($a.Ok -and $b.Ok)) { throw 'Old or new module does not compile' }
$diff = Compare-Contract (Get-Contract $a.Template) (Get-Contract $b.Template)

$callers = Get-ChildItem $script:RepoRoot -Recurse -Filter *.bicep -File |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.Name -ne $oldName -and $_.Name -ne $newName } |
    Where-Object { (Get-Content $_.FullName -Raw) -match [regex]::Escape($oldName) } |
    Sort-Object FullName

$rows = New-Object System.Collections.Generic.List[string]
foreach ($c in $callers) {
    $rel = $c.FullName.Substring($script:RepoRoot.Length + 1) -replace '\\', '/'
    $scratch = Join-Path $c.DirectoryName ('.blast-' + $c.Name)
    try {
        $text = (Get-Content $c.FullName -Raw).Replace($oldName, $newName)
        [IO.File]::WriteAllText($scratch, $text)
        $r = Invoke-BicepBuild $scratch
    }
    finally { Remove-Item $scratch -ErrorAction SilentlyContinue }
    $codes = @([regex]::Matches($r.Diagnostics, 'BCP\d+') | ForEach-Object Value | Sort-Object -Unique) -join ', '
    if ($r.Ok) { $rows.Add("| ``$rel`` | still compiles | - |") }
    else { $rows.Add("| ``$rel`` | **breaks** | $codes |") }
}
$broken = @($rows | Where-Object { $_ -match '\*\*breaks\*\*' }).Count

$changes = ($diff.Changes | ForEach-Object { "| $($_.Level) | $($_.Text) |" }) -join "`n"
$report = @"
# Blast radius: $oldName -> $newName

Offline report. Regenerate with ``./tests/blast-radius.ps1`` (``-Check`` fails if this file is stale).
It only sees callers inside this repository; callers in other repositories are why a major bump needs a migration guide.

## Contract changes

| Level | Change |
|---|---|
$changes

Required version bump: **$($diff.RequiredBump)**

## Callers that reference ``$oldName``, re-pointed at ``$newName``

| Caller | Result against $newName | Compiler codes |
|---|---|---|
$($rows -join "`n")

$broken of $($rows.Count) callers break. Codes: ``BCP035`` = required property missing, ``BCP083`` = property does not exist (a renamed output).
Fix: pass the new required parameter and read the renamed output; see ``05-breaking-change/MIGRATION.md``.
"@

$out = Get-RepoPath 'evidence/blast-radius.md'
$report = ($report -replace "`r`n", "`n").TrimEnd() + "`n"
if ($Check) {
    $current = (Get-Content $out -Raw) -replace "`r`n", "`n"
    if ($current -ne $report) { Write-Host 'evidence/blast-radius.md is stale. Run ./tests/blast-radius.ps1'; exit 1 }
    Write-Host 'evidence/blast-radius.md is up to date'
    exit 0
}
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
[IO.File]::WriteAllText($out, $report)
Write-Host $report
