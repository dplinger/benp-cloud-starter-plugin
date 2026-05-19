param(
    [ValidateSet("list", "start", "stop", "start-all", "health", "table")]
    [string]$Action = "list",
    [string]$Name = ""
)

$BaseUrl = "http://127.0.0.1:58080"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataFile = "$ScriptDir\modules.json"

# 从 modules.json 加载数据
$data = Get-Content $DataFile -Raw -Encoding UTF8 | ConvertFrom-Json
$CoreOrder = $data.coreOrder
$ModuleMap = @{}
$data.moduleMap.PSObject.Properties | ForEach-Object { $ModuleMap[$_.Name] = $_.Value }
$CategoryTable = $data.categoryTable

function Resolve-Name {
    param([string]$InputName)
    if ($ModuleMap.ContainsKey($InputName)) { return $ModuleMap[$InputName] }
    if ($ModuleMap.Values -contains $InputName) { return $InputName }
    return $InputName
}

function Call-Plugin {
    param([string]$Method, [string]$Path, [string]$Body)
    $headers = @{"Content-Type" = "application/json; charset=utf-8"}
    $uri = "$BaseUrl$Path"
    try {
        if ($Method -eq "GET") {
            Invoke-RestMethod -Uri $uri -Method GET -TimeoutSec 5
        } else {
            Invoke-RestMethod -Uri $uri -Method $Method -Body $Body -Headers $headers -TimeoutSec 5
        }
    } catch {
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Check-Health {
    $r = Call-Plugin -Method "GET" -Path "/health"
    if ($r -and $r.status -eq "ok") {
        Write-Host "[OK] Plugin connected" -ForegroundColor Green
        return $true
    }
    Write-Host "[FAIL] Cannot connect to plugin" -ForegroundColor Red
    return $false
}

function Show-Table {
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "  BNEP Cloud 模块列表" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    $cats = $CategoryTable | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    foreach ($cat in $cats) {
        Write-Host ""
        Write-Host "  [$cat]" -ForegroundColor Yellow
        $items = $CategoryTable.$cat
        foreach ($m in $items) {
            Write-Host ("    {0,-35} {1}" -f $m.name, $m.cn) -ForegroundColor White
        }
    }
    Write-Host ""
    Write-Host "使用方式: -Action start -Name ""网关"" 或 -Name ""GatewayServerApplication""" -ForegroundColor DarkGray
    Write-Host ""
}

function Start-Config {
    param([string]$ConfigName)
    Write-Host "Starting (debug): $ConfigName ..." -ForegroundColor Yellow
    $body = "{""name"":""$ConfigName""}"
    $r = Call-Plugin -Method "POST" -Path "/run" -Body $body
    if ($r -and $r.status -eq "started") {
        Write-Host "[OK] $ConfigName started" -ForegroundColor Green
    } elseif ($r -and $r.error) {
        Write-Host "[FAIL] $($r.error)" -ForegroundColor Red
    }
}

function Stop-Config {
    param([string]$ConfigName)
    Write-Host "Stopping: $ConfigName ..." -ForegroundColor Yellow
    $body = "{""name"":""$ConfigName""}"
    $r = Call-Plugin -Method "POST" -Path "/stop" -Body $body
    if ($r -and $r.status -eq "stopped") {
        Write-Host "[OK] $ConfigName stopped" -ForegroundColor Green
    } elseif ($r -and $r.error) {
        Write-Host "[FAIL] $($r.error)" -ForegroundColor Red
    }
}

function Start-Core {
    Write-Host ""
    Write-Host "========== 启动核心模块 ==========" -ForegroundColor Cyan
    Write-Host "Order: $($CoreOrder -join ' -> ')" -ForegroundColor Cyan
    Write-Host ""
    foreach ($module in $CoreOrder) {
        Start-Config -ConfigName $module
        Write-Host "Waiting (10s)..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 10
    }
    Write-Host ""
    Write-Host "========== 核心模块启动完成 ==========" -ForegroundColor Cyan
}

switch ($Action) {
    "health" {
        $null = Check-Health
    }
    "table" {
        Show-Table
    }
    "list" {
        if (Check-Health) { Show-Table }
    }
    "start" {
        if (-not $Name) { Write-Host "Usage: -Name <模块名或中文名>" -ForegroundColor Red; Show-Table; return }
        $resolved = Resolve-Name -InputName $Name
        if (Check-Health) { Start-Config -ConfigName $resolved }
    }
    "stop" {
        if (-not $Name) { Write-Host "Usage: -Name <模块名或中文名>" -ForegroundColor Red; return }
        $resolved = Resolve-Name -InputName $Name
        if (Check-Health) { Stop-Config -ConfigName $resolved }
    }
    "start-all" {
        if (Check-Health) {
            Start-Core
            Write-Host ""
            Show-Table
            Write-Host "核心模块已启动。如需启动其他模块，" -ForegroundColor White
            Write-Host "请用 -Action start -Name ""模块名"" 指定。" -ForegroundColor White
        }
    }
}
