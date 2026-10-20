# Shared helpers for the offline tests. Dot-source this file: . "$PSScriptRoot/lib.ps1"
Set-StrictMode -Version 2.0

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Passes = 0

function Get-RepoPath([string] $Relative) {
    Join-Path $script:RepoRoot $Relative
}

# Runs `az bicep build|build-params` and returns Ok, the parsed template, and any diagnostics.
function Invoke-BicepBuild([string] $File, [switch] $Params) {
    $sub = 'build'
    if ($Params) { $sub = 'build-params' }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $all = @(& az bicep $sub --file $File --stdout 2>&1)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $prev }

    $errText = ($all | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] -or "$_" -match '^(ERROR|WARNING):' } | ForEach-Object { "$_" }) -join "`n"
    $stdout = ($all | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] -and "$_" -notmatch '^(ERROR|WARNING):' } | ForEach-Object { "$_" }) -join "`n"
    $template = $null
    $parameters = $null
    if ($code -eq 0 -and $stdout.Trim().StartsWith('{')) {
        $obj = $stdout | ConvertFrom-Json
        if ($Params) {
            $template = $obj.templateJson | ConvertFrom-Json
            $parameters = $obj.parametersJson | ConvertFrom-Json
        }
        else { $template = $obj }
    }
    [pscustomobject]@{ Ok = ($code -eq 0); Template = $template; Parameters = $parameters; Diagnostics = $errText }
}

function Assert-That([string] $Name, [bool] $Condition, [string] $Detail = '') {
    if ($Condition) {
        $script:Passes++
        Write-Host "  PASS  $Name"
    }
    else {
        $msg = $Name
        if ($Detail) { $msg = "$Name -- $Detail" }
        $script:Failures.Add($msg)
        Write-Host "  FAIL  $msg" -ForegroundColor Red
    }
}

function Write-TestSummary {
    Write-Host ''
    Write-Host ("{0} passed, {1} failed" -f $script:Passes, $script:Failures.Count)
    if ($script:Failures.Count -gt 0) {
        $script:Failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        return 1
    }
    return 0
}

# Resources may be an array (classic) or a dictionary keyed by symbolic name (languageVersion 2.0).
function Get-ResourceList($Container) {
    if ($null -eq $Container -or -not ($Container.PSObject.Properties.Name -contains 'resources')) { return @() }
    $r = $Container.resources
    if ($null -eq $r) { return @() }
    if ($r -is [System.Array]) { return @($r) }
    return @($r.PSObject.Properties | ForEach-Object { $_.Value })
}

# Flattens a compiled template, descending into nested deployments (modules).
function Get-AllResources($Template) {
    foreach ($res in Get-ResourceList $Template) {
        $res
        if ($res.type -eq 'Microsoft.Resources/deployments' -and $res.properties.PSObject.Properties.Name -contains 'template') {
            Get-AllResources $res.properties.template
        }
    }
}

function Get-ModuleDeployments($Template) {
    Get-ResourceList $Template | Where-Object { $_.type -eq 'Microsoft.Resources/deployments' }
}

function Get-NamesOf($Obj) {
    if ($null -eq $Obj) { return @() }
    @($Obj.PSObject.Properties | ForEach-Object { $_.Name } | Sort-Object)
}

# Describes a compiled template's public contract: parameters and outputs.
function Get-Contract($Template) {
    $params = @{}
    if ($Template.PSObject.Properties.Name -contains 'parameters') {
        foreach ($p in $Template.parameters.PSObject.Properties) {
            $allowed = @()
            if ($p.Value.PSObject.Properties.Name -contains 'allowedValues') { $allowed = @($p.Value.allowedValues) }
            $params[$p.Name] = [pscustomobject]@{
                Type     = $p.Value.type
                Required = -not ($p.Value.PSObject.Properties.Name -contains 'defaultValue')
                Allowed  = $allowed
            }
        }
    }
    $outs = @{}
    if ($Template.PSObject.Properties.Name -contains 'outputs') {
        foreach ($o in $Template.outputs.PSObject.Properties) { $outs[$o.Name] = $o.Value.type }
    }
    [pscustomobject]@{ Parameters = $params; Outputs = $outs }
}

# Compares two contracts and returns the changes plus the semver bump they require.
function Compare-Contract($Old, $New) {
    $changes = New-Object System.Collections.Generic.List[object]
    function Add-Change($Level, $Text) { $changes.Add([pscustomobject]@{ Level = $Level; Text = $Text }) }

    foreach ($name in ($Old.Parameters.Keys | Sort-Object)) {
        if (-not $New.Parameters.ContainsKey($name)) { Add-Change 'major' "parameter removed or renamed: $name"; continue }
        $o = $Old.Parameters[$name]; $n = $New.Parameters[$name]
        if ($o.Type -ne $n.Type) { Add-Change 'major' "parameter type changed: $name ($($o.Type) -> $($n.Type))" }
        if ($o.Required -eq $false -and $n.Required -eq $true) { Add-Change 'major' "parameter became required: $name" }
        if ($o.Allowed.Count -gt 0) {
            $removed = @($o.Allowed | Where-Object { $n.Allowed.Count -gt 0 -and $n.Allowed -notcontains $_ })
            $added = @($n.Allowed | Where-Object { $o.Allowed -notcontains $_ })
            if ($removed.Count -gt 0) { Add-Change 'major' "allowed values removed for ${name}: $($removed -join ', ')" }
            if ($added.Count -gt 0) { Add-Change 'minor' "allowed values added for ${name}: $($added -join ', ')" }
        }
    }
    foreach ($name in ($New.Parameters.Keys | Sort-Object)) {
        if ($Old.Parameters.ContainsKey($name)) { continue }
        if ($New.Parameters[$name].Required) { Add-Change 'major' "new required parameter: $name" }
        else { Add-Change 'minor' "new optional parameter: $name" }
    }
    foreach ($name in ($Old.Outputs.Keys | Sort-Object)) {
        if (-not $New.Outputs.ContainsKey($name)) { Add-Change 'major' "output removed or renamed: $name" }
        elseif ($Old.Outputs[$name] -ne $New.Outputs[$name]) { Add-Change 'major' "output type changed: $name" }
    }
    foreach ($name in ($New.Outputs.Keys | Sort-Object)) {
        if (-not $Old.Outputs.ContainsKey($name)) { Add-Change 'minor' "new output: $name" }
    }

    $bump = 'patch'
    if (@($changes | Where-Object Level -eq 'minor').Count -gt 0) { $bump = 'minor' }
    if (@($changes | Where-Object Level -eq 'major').Count -gt 0) { $bump = 'major' }
    [pscustomobject]@{ Changes = $changes.ToArray(); RequiredBump = $bump }
}
