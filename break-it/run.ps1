# Runs every break-it scenario offline and checks that it fails the way its README says.
# A scenario "passes" here when the expected failure is observed. Usage: ./break-it/run.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../tests/lib.ps1"

function Format-Line([string] $s) {
    $s = $s.Trim() -replace [regex]::Escape($script:RepoRoot + [IO.Path]::DirectorySeparatorChar), ''
    if ($s.Length -gt 170) { $s.Substring(0, 170) + '...' } else { $s }
}

function Show-Failure([string] $Text) {
    @($Text -split "`n" | Where-Object { $_.Trim() -and $_ -notmatch '^WARNING|RemoteException' } | Select-Object -First 2) | ForEach-Object { Write-Host "        $(Format-Line $_)" }
}

Write-Host '== 1. contract violation: environment=staging'
$r = Invoke-BicepBuild (Get-RepoPath 'break-it/01-contract-violation/dev-staging.bicepparam') -Params
Show-Failure $r.Diagnostics
Assert-That 'compiler rejects environment=staging (BCP033)' (-not $r.Ok -and $r.Diagnostics -match 'BCP033')

Write-Host '== 2. leaking a parameter: minimumTlsVersion'
$leaky = Invoke-BicepBuild (Get-RepoPath 'break-it/02-leak-a-parameter/storage.bicep')
$caller = Invoke-BicepBuild (Get-RepoPath 'break-it/02-leak-a-parameter/main.bicep')
$good = Invoke-BicepBuild (Get-RepoPath '02-extracted/modules/storage.bicep')
Assert-That 'the leaky module and a TLS 1.0 caller both compile (the compiler cannot help)' ($leaky.Ok -and $caller.Ok) ($leaky.Diagnostics + $caller.Diagnostics)
$diff = Compare-Contract (Get-Contract $good.Template) (Get-Contract $leaky.Template)
$diff.Changes | ForEach-Object { Write-Host ("        [{0}] {1}" -f $_.Level, $_.Text) }
Assert-That 'contract diff flags the new parameter minimumTlsVersion' (($diff.Changes | ForEach-Object Text) -contains 'new optional parameter: minimumTlsVersion')

Write-Host '== 3. un-migrated caller against v2'
$r = Invoke-BicepBuild (Get-RepoPath 'break-it/03-unmigrated-caller/consumer.bicep')
Show-Failure $r.Diagnostics
Assert-That 'compiler rejects the v1-style caller (BCP035, BCP083)' (-not $r.Ok -and $r.Diagnostics -match 'BCP035' -and $r.Diagnostics -match 'BCP083')

Write-Host '== 4. silent drift: retention 30 -> 31'
$out = @(& pwsh -NoProfile -File (Get-RepoPath 'tests/what-if-equivalence.ps1') -Candidate 'break-it/04-silent-drift/main.bicep' 2>&1 | ForEach-Object { "$_" })
$out | Where-Object { $_ -match 'FAIL' } | Select-Object -First 1 | ForEach-Object { Write-Host "        $(Format-Line $_)" }
Assert-That 'equivalence test fails for the drifted module' ($LASTEXITCODE -ne 0)

exit (Write-TestSummary)
