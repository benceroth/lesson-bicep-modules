# Contract tests for the Northstar storage module. Offline by default: compiles Bicep with
# `az bicep` and inspects the generated ARM JSON. Add -Live -ResourceGroup <rg> to also run
# `az deployment group validate` against a real resource group (requires az login).
param(
    [switch] $Live,
    [string] $ResourceGroup
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/lib.ps1"

$modulePath = Get-RepoPath '02-extracted/modules/storage.bicep'
$mainPath = Get-RepoPath '02-extracted/main.bicep'

Write-Host '== 1. Module contract: inputs and outputs'
$m = Invoke-BicepBuild $modulePath
Assert-That 'storage.bicep compiles' $m.Ok $m.Diagnostics
$contract = Get-Contract $m.Template
Assert-That 'module has exactly two parameters: environment, skuName' (($contract.Parameters.Keys | Sort-Object) -join ',' -eq 'environment,skuName')
Assert-That 'environment allows exactly dev,test,prod' ((@($contract.Parameters['environment'].Allowed) | Sort-Object) -join ',' -eq 'dev,prod,test')
Assert-That 'skuName allows exactly Standard_LRS,Standard_ZRS' ((@($contract.Parameters['skuName'].Allowed) | Sort-Object) -join ',' -eq 'Standard_LRS,Standard_ZRS')
Assert-That 'module has exactly two outputs: storageAccountId, storageAccountName' (($contract.Outputs.Keys | Sort-Object) -join ',' -eq 'storageAccountId,storageAccountName')

Assert-That 'both outputs are strings' (@($contract.Outputs.Values | Where-Object { $_ -ne 'string' }).Count -eq 0)
Assert-That 'storageAccountId is the storage account resource ID' (
    $m.Template.outputs.storageAccountId.value -eq "[resourceId('Microsoft.Storage/storageAccounts', variables('storageAccountName'))]")
Assert-That 'no parameter is @secure' (@($m.Template.parameters.PSObject.Properties | Where-Object { $_.Value.type -in @('securestring', 'secureObject') }).Count -eq 0)

Write-Host '== 2. Module-owned settings'
$resources = @(Get-AllResources $m.Template)
$account = $resources | Where-Object { $_.type -eq 'Microsoft.Storage/storageAccounts' }
$blob = $resources | Where-Object { $_.type -eq 'Microsoft.Storage/storageAccounts/blobServices' }
Assert-That 'one storage account and one blob service' (@($account).Count -eq 1 -and @($blob).Count -eq 1)
Assert-That 'HTTPS only is true (literal, not a parameter)' ($account.properties.supportsHttpsTrafficOnly -eq $true)
Assert-That 'minimum TLS is TLS1_2 (literal)' ($account.properties.minimumTlsVersion -eq 'TLS1_2')
Assert-That 'public blob access is false (literal)' ($account.properties.allowBlobPublicAccess -eq $false)
Assert-That 'location is westeurope (literal)' ($account.location -eq 'westeurope')
Assert-That 'kind is StorageV2' ($account.kind -eq 'StorageV2')
Assert-That 'delete retention enabled for 30 days' ($blob.properties.deleteRetentionPolicy.enabled -eq $true -and $blob.properties.deleteRetentionPolicy.days -eq 30)
Assert-That 'tags: application=notes, owner=platform-team, environment from parameter' (
    $account.tags.application -eq 'notes' -and $account.tags.owner -eq 'platform-team' -and $account.tags.environment -eq "[parameters('environment')]")
Assert-That 'sku comes from the skuName parameter' ($account.sku.name -eq "[parameters('skuName')]")
Assert-That 'name formula is st<environment><uniqueString(resourceGroup().id)>' (
    $m.Template.variables.storageAccountName -eq "[format('st{0}{1}', parameters('environment'), uniqueString(resourceGroup().id))]")

Write-Host '== 3. Parent template and parameter files'
$p = Invoke-BicepBuild $mainPath
Assert-That 'main.bicep compiles' $p.Ok $p.Diagnostics
$deployment = @(Get-ModuleDeployments $p.Template)[0]
Assert-That 'module receives only environment and skuName' ((Get-NamesOf $deployment.properties.parameters) -join ',' -eq 'environment,skuName')
Assert-That 'deployment name includes the environment' ($deployment.name -eq "[format('northstar-storage-{0}', parameters('environment'))]")
Assert-That 'main exposes exactly the two module outputs' ((Get-NamesOf $p.Template.outputs) -join ',' -eq 'storageAccountId,storageAccountName')

# Evaluate the SKU selection expression for each environment.
$expr = $p.Template.variables.skuName
$rx = "^\[if\(equals\(parameters\('environment'\), '(\w+)'\), '(\w+)', '(\w+)'\)\]$"
Assert-That 'sku selection is a simple environment conditional' ($expr -match $rx) $expr
$expected = @{ dev = 'Standard_LRS'; test = 'Standard_LRS'; prod = 'Standard_ZRS' }
foreach ($env in 'dev', 'test', 'prod') {
    $pf = Invoke-BicepBuild (Get-RepoPath "02-extracted/params/$env.bicepparam") -Params
    $ok = $pf.Ok -and $pf.Parameters.parameters.environment.value -eq $env
    Assert-That "params/$env.bicepparam compiles with environment=$env" $ok $pf.Diagnostics
    $sku = $null
    if ($expr -match $rx) {
        if ($env -eq $Matches[1]) { $sku = $Matches[2] } else { $sku = $Matches[3] }
    }
    Assert-That "environment=$env selects $($expected[$env])" ($sku -eq $expected[$env]) "got $sku"
}

Write-Host '== 4. Bad inputs are rejected at compile time'
$bad = @(
    @{ File = 'bad-env.bicepparam'; Code = 'BCP033'; Why = "environment=staging" },
    @{ File = 'bad-sku.bicepparam'; Code = 'BCP033'; Why = "skuName=Premium_LRS" },
    @{ File = 'bad-policy-param.bicepparam'; Code = 'BCP259'; Why = "minimumTlsVersion cannot be passed" }
)
foreach ($b in $bad) {
    $r = Invoke-BicepBuild (Get-RepoPath "tests/fixtures/$($b.File)") -Params
    Assert-That "rejected: $($b.Why) ($($b.Code))" (-not $r.Ok -and $r.Diagnostics -match $b.Code) $r.Diagnostics
}
# The compiled template also carries the constraint, so ARM rejects the same values at deployment time.
Assert-That 'compiled template keeps allowedValues for ARM-side validation' (
    @($m.Template.parameters.environment.allowedValues).Count -eq 3 -and @($m.Template.parameters.skuName.allowedValues).Count -eq 2)

Write-Host '== 5. Contrast: the parts-bin module has no such contract'
$pb = Invoke-BicepBuild (Get-RepoPath '03-anti-pattern-parts-bin/modules/storage-everything.bicep')
Assert-That 'parts-bin module compiles' $pb.Ok $pb.Diagnostics
$pbc = Get-Contract $pb.Template
$unconstrained = @($pbc.Parameters.Values | Where-Object { $_.Allowed.Count -eq 0 }).Count
Write-Host ("  INFO  parts-bin: {0} parameters, {1} without @allowed, {2} outputs (measured on this repo)" -f $pbc.Parameters.Count, $unconstrained, $pbc.Outputs.Count)
Assert-That 'parts-bin exposes policy settings as parameters' (
    $pbc.Parameters.ContainsKey('minimumTlsVersion') -and $pbc.Parameters.ContainsKey('allowBlobPublicAccess') -and $pbc.Parameters.ContainsKey('deleteRetentionDays'))
Assert-That 'parts-bin has far more parameters than the contract module' ($pbc.Parameters.Count -gt 5 * $contract.Parameters.Count)
$weak = Invoke-BicepBuild (Get-RepoPath '03-anti-pattern-parts-bin/main.bicep')
Assert-That 'a policy-violating caller compiles against the parts-bin module' $weak.Ok $weak.Diagnostics

Write-Host '== 6. Breaking change: v1 -> v2'
$v1 = Invoke-BicepBuild (Get-RepoPath '05-breaking-change/storage-v1.bicep')
$v2 = Invoke-BicepBuild (Get-RepoPath '05-breaking-change/storage-v2.bicep')
Assert-That 'storage-v1 and storage-v2 compile' ($v1.Ok -and $v2.Ok) ($v1.Diagnostics + $v2.Diagnostics)
$self = Compare-Contract (Get-Contract $m.Template) (Get-Contract $v1.Template)
Assert-That 'v1 has the same contract as 02-extracted (no bump)' ($self.Changes.Count -eq 0) (($self.Changes | ForEach-Object Text) -join '; ')
$diff = Compare-Contract (Get-Contract $v1.Template) (Get-Contract $v2.Template)
Assert-That 'v1 -> v2 requires a major bump' ($diff.RequiredBump -eq 'major')
Assert-That 'diff reports the new required parameter and the renamed output' (
    (($diff.Changes | ForEach-Object Text) -contains 'new required parameter: costCenter') -and
    (($diff.Changes | ForEach-Object Text) -contains 'output removed or renamed: storageAccountName'))
Assert-That 'consumer-v1 compiles against v1' (Invoke-BicepBuild (Get-RepoPath '05-breaking-change/consumer-v1.bicep')).Ok
Assert-That 'consumer-v2 (migrated) compiles against v2' (Invoke-BicepBuild (Get-RepoPath '05-breaking-change/consumer-v2.bicep')).Ok
$un = Invoke-BicepBuild (Get-RepoPath 'tests/fixtures/consumer-unmigrated-v2.bicep')
Assert-That 'un-migrated caller fails against v2 (BCP035, BCP083)' (-not $un.Ok -and $un.Diagnostics -match 'BCP035' -and $un.Diagnostics -match 'BCP083') $un.Diagnostics
# The deployed policy must not change in v2.
$a2 = @(Get-AllResources $v2.Template) | Where-Object { $_.type -eq 'Microsoft.Storage/storageAccounts' }
Assert-That 'v2 keeps HTTPS/TLS/public-access policy' ($a2.properties.supportsHttpsTrafficOnly -eq $true -and $a2.properties.minimumTlsVersion -eq 'TLS1_2' -and $a2.properties.allowBlobPublicAccess -eq $false)

if ($Live) {
    Write-Host '== 7. Live: az deployment group validate (opt-in)'
    if (-not $ResourceGroup) { throw '-Live requires -ResourceGroup' }
    $null = & az deployment group validate -g $ResourceGroup -f $mainPath -p environment=dev -o none 2>&1
    Assert-That 'validate accepts environment=dev' ($LASTEXITCODE -eq 0)
    $null = & az deployment group validate -g $ResourceGroup -f $mainPath -p environment=staging -o none 2>&1
    Assert-That 'validate rejects environment=staging' ($LASTEXITCODE -ne 0)
    $null = & az deployment group validate -g $ResourceGroup -f $modulePath -p environment=prod skuName=Premium_LRS -o none 2>&1
    Assert-That 'validate rejects skuName=Premium_LRS' ($LASTEXITCODE -ne 0)
}

exit (Write-TestSummary)
