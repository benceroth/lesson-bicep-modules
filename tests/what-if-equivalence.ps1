# Proves the refactor from 01-flat-baseline to 02-extracted does not change what is deployed.
#
# Offline (default): compiles both templates, resolves variables/parameters (including across the
# module boundary) and compares every deployed resource for each environment. No Azure access.
#
# -Candidate <repo-relative main.bicep> compares a different parent (default 02-extracted/main.bicep); break-it/ uses it.
#
# Live (opt-in): -Live -ResourceGroup <existing scratch rg>. Deploys 01 into the resource group,
# then runs `az deployment group what-if` for 02 and expects no resource changes. This creates
# a real (cheap) storage account; delete the resource group afterwards.
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch] $Live,
    [string] $ResourceGroup,
    [ValidateSet('dev', 'test', 'prod')] [string] $Environment = 'dev',
    [string] $Candidate = '02-extracted/main.bicep'
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/lib.ps1"

# Turns an ARM value into expression text without the outer brackets so it can be spliced into another expression.
function ConvertTo-InnerExpression($Value) {
    if ($Value -is [string]) {
        if ($Value.StartsWith('[') -and $Value.EndsWith(']') -and -not $Value.StartsWith('[[')) { return $Value.Substring(1, $Value.Length - 2) }
        return "'" + $Value + "'"
    }
    if ($Value -is [bool]) { return $Value.ToString().ToLowerInvariant() }
    return [string]$Value
}

# Substitutes variables() and parameters() so templates with different structure can be compared.
function Resolve-Text([string] $Text, $Variables, [hashtable] $ParamMap) {
    if (-not ($Text.StartsWith('[') -and $Text.EndsWith(']')) -or $Text.StartsWith('[[')) { return $Text }
    $inner = $Text.Substring(1, $Text.Length - 2)
    for ($i = 0; $i -lt 10 -and $inner -match "variables\('(\w+)'\)"; $i++) {
        $inner = [regex]::Replace($inner, "variables\('(\w+)'\)", {
                param($m)
                ConvertTo-InnerExpression $Variables.($m.Groups[1].Value)
            })
    }
    $inner = [regex]::Replace($inner, "parameters\('(\w+)'\)", {
            param($m)
            $n = $m.Groups[1].Value
            if ($ParamMap.ContainsKey($n)) { $ParamMap[$n] } else { $m.Value }
        })
    "[$inner]"
}

function Resolve-Node($Node, $Variables, [hashtable] $ParamMap) {
    if ($Node -is [string]) { return Resolve-Text $Node $Variables $ParamMap }
    if ($Node -is [System.Array]) { return @($Node | ForEach-Object { Resolve-Node $_ $Variables $ParamMap }) }
    if ($Node -is [pscustomobject]) {
        $o = [ordered]@{}
        foreach ($p in ($Node.PSObject.Properties | Sort-Object Name)) { $o[$p.Name] = Resolve-Node $p.Value $Variables $ParamMap }
        return $o
    }
    return $Node
}

function Get-Variables($Template) {
    if ($Template.PSObject.Properties.Name -contains 'variables') { return $Template.variables }
    return [pscustomobject]@{}
}

# Returns a hashtable: "type|resolved name" -> canonical JSON of the resolved resource.
function Get-ResolvedResources($Template, [hashtable] $ParamMap) {
    $result = @{}
    $vars = Get-Variables $Template
    foreach ($res in Get-ResourceList $Template) {
        if ($res.type -eq 'Microsoft.Resources/deployments') {
            $childMap = @{}
            foreach ($p in $res.properties.parameters.PSObject.Properties) {
                $childMap[$p.Name] = ConvertTo-InnerExpression (Resolve-Node $p.Value.value $vars $ParamMap)
            }
            $child = Get-ResolvedResources $res.properties.template $childMap
            foreach ($k in $child.Keys) { $result[$k] = $child[$k] }
        }
        else {
            $resolved = Resolve-Node $res $vars $ParamMap
            $result["$($res.type)|$($resolved['name'])"] = ($resolved | ConvertTo-Json -Depth 20 -Compress)
        }
    }
    $result
}

if (-not $Live) {
    Write-Host '== Offline equivalence: 01-flat-baseline vs 02-extracted'
    $flat = Invoke-BicepBuild (Get-RepoPath '01-flat-baseline/main.bicep')
    $mod = Invoke-BicepBuild (Get-RepoPath $Candidate)
    Assert-That '01-flat-baseline compiles' $flat.Ok $flat.Diagnostics
    Assert-That '02-extracted compiles' $mod.Ok $mod.Diagnostics

    $a = Get-ResolvedResources $flat.Template @{}
    $b = Get-ResolvedResources $mod.Template @{}
    Assert-That 'both deploy the same set of resources' ((($a.Keys | Sort-Object) -join "`n") -eq (($b.Keys | Sort-Object) -join "`n")) ("flat: " + ($a.Keys -join '; ') + " | modules: " + ($b.Keys -join '; '))
    foreach ($k in ($a.Keys | Sort-Object)) {
        Assert-That "identical resolved definition: $k" ($b.ContainsKey($k) -and $a[$k] -eq $b[$k]) "flat=$($a[$k]) module=$($b[$k])"
    }
    $oa = (Get-Contract $flat.Template).Outputs
    $ob = (Get-Contract $mod.Template).Outputs
    Assert-That 'outputs have identical names and types' ((($oa.Keys | Sort-Object | ForEach-Object { "$_=$($oa[$_])" }) -join ',') -eq (($ob.Keys | Sort-Object | ForEach-Object { "$_=$($ob[$_])" }) -join ','))
    Write-Host '  Note: resolved definitions keep parameters(''environment'') symbolic, so this holds for dev, test and prod alike.'
    exit (Write-TestSummary)
}

Write-Host "== Live equivalence in resource group '$ResourceGroup' (environment=$Environment)"
if (-not $ResourceGroup) { throw '-Live requires -ResourceGroup (an existing scratch resource group)' }
$flatFile = Get-RepoPath '01-flat-baseline/main.bicep'
$modFile = Get-RepoPath $Candidate

if ($PSCmdlet.ShouldProcess($ResourceGroup, "Deploy 01-flat-baseline ($Environment)")) {
    az deployment group create --name "equivalence-baseline-$Environment" -g $ResourceGroup -f $flatFile -p environment=$Environment -o none
    if ($LASTEXITCODE -ne 0) { throw 'Baseline deployment failed.' }
}
$json = az deployment group what-if -g $ResourceGroup -f $modFile -p environment=$Environment --no-pretty-print -o json
if ($LASTEXITCODE -ne 0) { throw 'what-if failed.' }
$changes = @(($json | ConvertFrom-Json).changes)
$real = @($changes | Where-Object { $_.changeType -notin @('NoChange', 'Ignore') })
$changes | ForEach-Object { Write-Host ("  {0,-9} {1}" -f $_.changeType, $_.resourceId) }
Assert-That 'what-if reports no resource changes' ($real.Count -eq 0) (($real | ForEach-Object { "$($_.changeType) $($_.resourceId)" }) -join '; ')
exit (Write-TestSummary)
