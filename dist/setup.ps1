# BNEP Cloud 开发环境一键 Setup
# Usage: .\setup.ps1 -ProjectPath "D:\Java\code\bnep-cloud"
param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath
)

$ErrorActionPreference = "Continue"
$DistDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PluginJar = "$DistDir\bnep-cloud-starter-plugin.jar"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BNEP Cloud Dev Environment Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Project: $ProjectPath" -ForegroundColor DarkGray
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "[ERROR] Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# ---- 1. Generate Run Configurations ----
Write-Host "[1/5] Generating Run Configurations..." -ForegroundColor Yellow
& "$DistDir\gen-run-configs.ps1" -ProjectPath $ProjectPath

# ---- 2. dynamic.classpath ----
Write-Host "[2/5] Configuring dynamic.classpath..." -ForegroundColor Yellow
$workspace = "$ProjectPath\.idea\workspace.xml"
if (Test-Path $workspace) {
    $content = Get-Content $workspace -Raw -Encoding UTF8
    if ($content -match '"dynamic\.classpath"\s*:\s*"true"') {
        Write-Host "  [OK] Already configured" -ForegroundColor Green
    } else {
        $content = $content -replace '("keyToString"\s*:\s*\{)', ('$1' + "`r`n    `"dynamic.classpath`": `"true`",")
        $content | Set-Content $workspace -Encoding UTF8 -NoNewline
        Write-Host "  [OK] Added dynamic.classpath to workspace.xml" -ForegroundColor Green
    }
} else {
    Write-Host "  [WARN] workspace.xml not found. Open project in IDEA first." -ForegroundColor Yellow
}

# ---- 3. Copy Skills to project ----
Write-Host "[3/5] Installing Claude Code skills..." -ForegroundColor Yellow
$destSkills = "$ProjectPath\.claude\skills\start-project"
New-Item -ItemType Directory -Force $destSkills | Out-Null
Copy-Item "$DistDir\skills\start-project\*" $destSkills -Force
Write-Host "  [OK] Skills installed to .claude\skills\start-project\" -ForegroundColor Green

# ---- 4. Auto-install IDEA plugin ----
Write-Host "[4/5] Installing IDEA plugin..." -ForegroundColor Yellow

# Detect IDEA plugins directory
$pluginsDir = $null
$jetbrainsDir = "$env:APPDATA\JetBrains"
if (Test-Path $jetbrainsDir) {
    $ideaDirs = Get-ChildItem $jetbrainsDir -Directory |
        Where-Object { $_.Name -match '^(IntelliJIdea|IdeaIC)' } |
        Sort-Object Name -Descending
    if ($ideaDirs.Count -gt 0) {
        $pluginsDir = "$($ideaDirs[0].FullName)\plugins"
        Write-Host "  Found IDEA plugins dir: $pluginsDir" -ForegroundColor DarkGray
    }
}

if (-not $pluginsDir) {
    Write-Host "  [WARN] IDEA plugins directory not found" -ForegroundColor Yellow
    Write-Host "  Manual install: Settings -> Plugins -> Install from Disk -> $PluginJar" -ForegroundColor White
} else {
    Copy-Item $PluginJar "$pluginsDir\bnep-cloud-starter-plugin.jar" -Force
    Write-Host "  [OK] Plugin installed to: $pluginsDir" -ForegroundColor Green
    Write-Host "  PLEASE RESTART IDEA to activate the plugin" -ForegroundColor Yellow
}

# ---- 5. Verify plugin ----
Write-Host "[5/5] Verifying..." -ForegroundColor Yellow
try {
    $r = Invoke-RestMethod -Uri "http://127.0.0.1:58080/health" -Method GET -TimeoutSec 3 -ErrorAction Stop
    if ($r.status -eq "ok") {
        Write-Host "  [OK] Plugin is running" -ForegroundColor Green
    }
} catch {
    Write-Host "  [INFO] Plugin will be available after IDEA restart" -ForegroundColor DarkGray
}

# ---- Summary ----
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next:" -ForegroundColor White
Write-Host "  1. Restart IDEA (if plugin was just installed)" -ForegroundColor White
Write-Host "  2. Reload project: File -> Reload All from Disk" -ForegroundColor White
Write-Host "  3. Start: .claude\skills\start-project\scripts\start-modules.ps1 -Action start-all" -ForegroundColor White
Write-Host ""
