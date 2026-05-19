# Scan BNEP Cloud project, discover modules, update modules.json + run configs
param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath
)

if (-not (Test-Path "$ProjectPath\pom.xml")) {
    Write-Host "[ERROR] Not a Maven project: $ProjectPath" -ForegroundColor Red
    exit 1
}

Write-Host "Scanning: $ProjectPath" -ForegroundColor Cyan

# Step 1: Discover all SpringBootApplication main classes
$mainClasses = @{}
Get-ChildItem -Path $ProjectPath -Recurse -Filter "*.java" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "\\target\\" } |
    Select-String '@SpringBootApplication' -List |
    ForEach-Object {
        $path = $_.Path
        $raw = (Get-Content $path -Raw -Encoding UTF8) -replace "`r`n","`n"
        $pkg = ""
        if ($raw -match 'package\s+([\w.]+)\s*;') { $pkg = $matches[1] }
        $className = [System.IO.Path]::GetFileNameWithoutExtension($path)
        $mainClasses[$className] = "$pkg.$className"
    }
Write-Host "  Found $($mainClasses.Count) @SpringBootApplication classes" -ForegroundColor Green

# Step 2: Read module descriptions from parent pom.xml
$modDesc = @{}
Get-ChildItem -Path $ProjectPath -Directory -Depth 0 |
    Where-Object { $_.Name -match '^bnep-' } |
    ForEach-Object {
        $modDir = $_.Name
        $pomPath = "$ProjectPath\$modDir\pom.xml"
        if (Test-Path $pomPath) {
            $pom = Get-Content $pomPath -Raw -Encoding UTF8
            if ($pom -match '<description>([^<]+)</description>') {
                $modDesc[$modDir] = $matches[1].Trim()
                Write-Host "  $modDir -> $($modDesc[$modDir])"
            }
        }
    }

if ($modDesc.Count -eq 0) {
    Write-Host "[WARN] No module descriptions found" -ForegroundColor Yellow
    exit 1
}

# Step 3: Categorize modules
# Category order (Chinese names)
$catBase = "基础服务"
$catData = "基础数据服务"
$catCore = "核心业务服务"
$catAggr = "上层聚合服务"
$catSpec = "特殊服务"
$catSupp = "支撑服务"

$catModules = @{}
@($catBase, $catData, $catCore, $catAggr, $catSpec, $catSupp) | ForEach-Object { $catModules[$_] = @() }

foreach ($mod in $modDesc.Keys) {
    if ($mod -eq "bnep-gateway" -or $mod -eq "bnep-base" -or $mod -eq "bnep-basic") { $cat = $catBase }
    elseif ($mod -eq "bnep-iot" -or $mod -eq "bnep-source" -or $mod -eq "bnep-operator" -or $mod -eq "bnep-atmosphere" -or $mod -eq "bnep-water") { $cat = $catData }
    elseif ($mod -eq "bnep-analysis" -or $mod -eq "bnep-bigscreen" -or $mod -eq "bnep-carbon") { $cat = $catAggr }
    elseif ($mod -eq "bnep-aiInfrastructure") { $cat = $catSpec }
    elseif ($mod -eq "bnep-monitor" -or $mod -eq "bnep-support") { $cat = $catSupp }
    elseif ($mod -match "bnep-(communal|communalAux|control|check|event|offsite|notice|flowable|dossier|datatransfer)") { $cat = $catCore }
    else { $cat = $catCore }

    $catModules[$cat] += @{module=$mod; desc=$modDesc[$mod]}
}

# Step 4: Match main classes to modules and build output data
$coreOrder = @("GatewayServerApplication", "BaseServerApplication")

$moduleMap = @{}
$moduleMap["网关"] = "GatewayServerApplication"
$moduleMap["网关服务"] = "GatewayServerApplication"
$moduleMap["base"] = "BaseServerApplication"
$moduleMap["基础服务"] = "BaseServerApplication"
$moduleMap["数智答"] = "AiInfrastructureServerApplication"
$moduleMap["AI"] = "AiInfrastructureServerApplication"
$moduleMap["AI基础设施"] = "AiInfrastructureServerApplication"

$categoryTable = [ordered]@{}
$catOrder = @($catBase, $catData, $catCore, $catAggr, $catSpec, $catSupp)

foreach ($cat in $catOrder) {
    $items = @()
    foreach ($m in $catModules[$cat]) {
        $modDir = $m.module
        $modShort = $modDir -replace '^bnep-',''
        $configName = $null

        foreach ($cn in $mainClasses.Keys) {
            $fq = $mainClasses[$cn]
            if ($cn -eq "GatewayServerApplication" -and $modDir -eq "bnep-gateway") { $configName = $cn; break }
            if ($cn -eq "MonitorServerApplication" -and $modDir -eq "bnep-support") { $configName = $cn; break }
            if ($fq -match "com\.bnep\.$modShort") { $configName = $cn; break }
        }

        if ($configName) {
            $items += @{name=$configName; cn=$m.desc}
            if (-not $moduleMap.ContainsKey($m.desc)) {
                $moduleMap[$m.desc] = $configName
            }
        } else {
            Write-Host "  [WARN] No main class matched for $modDir" -ForegroundColor Yellow
        }
    }
    if ($items.Count -gt 0) {
        $categoryTable[$cat] = $items
    }
}

# Step 5: Write modules.json
$output = [ordered]@{
    coreOrder     = $coreOrder
    moduleMap     = $moduleMap
    categoryTable = $categoryTable
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outFile = "$ScriptDir\modules.json"
$json = $output | ConvertTo-Json -Depth 4
$enc = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($outFile, $json, $enc)

Write-Host ""
Write-Host "[OK] Updated: $outFile" -ForegroundColor Green

# Step 6: Sync run configuration XMLs
$runDir = "$ProjectPath\.idea\runConfigurations"
New-Item -ItemType Directory -Force $runDir | Out-Null
$cnt = 0
foreach ($cat in $categoryTable.Keys) {
    foreach ($m in $categoryTable[$cat]) {
        $xml = @"
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="$($m.name)" type="Application" factoryName="Application" nameIsGenerated="true">
    <option name="MAIN_CLASS_NAME" value="$($m.name)" />
    <module name="bnep-gateway-server" />
    <method v="2">
      <option name="Make" enabled="true" />
    </method>
  </configuration>
</component>
"@
        $xml | Out-File -FilePath "$runDir\$($m.name).xml" -Encoding utf8 -NoNewline
        $cnt++
    }
}
Write-Host "[OK] $cnt run configurations in $runDir" -ForegroundColor Green
