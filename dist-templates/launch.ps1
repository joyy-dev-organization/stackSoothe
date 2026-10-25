# StackSoothe One-Click Windows Launcher Orchestrator
# Handles prerequisite checking, port defense, readiness polling, and owned cleanup.

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  StackSoothe -- Local Flutter & Dart Debugging Assistant" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Duplicate launch detection
$RunningApps = Get-Process -Name "stacksoothe" -ErrorAction SilentlyContinue
if ($RunningApps) {
    Write-Host "`n[INFO] StackSoothe desktop application is already running (PID: $($RunningApps.Id -join ', '))." -ForegroundColor Yellow
    Write-Host "Please switch to the existing window. Closing launcher." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    exit 0
}

# 2. Port 11435 conflict and collision defense
$ServiceAlreadyRunning = $false
$PortInUse = Get-NetTCPConnection -LocalPort 11435 -ErrorAction SilentlyContinue
if ($PortInUse) {
    try {
        $Health = Invoke-RestMethod -Uri "http://127.0.0.1:11435/health" -Method Get -TimeoutSec 2 -ErrorAction Stop
        if ($Health.service -eq "stacksoothe-service") {
            Write-Host "`n[INFO] Reusing active StackSoothe service on port 11435." -ForegroundColor Yellow
            $ServiceAlreadyRunning = $true
        } else {
            Write-Host "`n[ERROR] Port 11435 is occupied by an alien application." -ForegroundColor Red
            Write-Host "Please free port 11435 before starting StackSoothe." -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "`n[ERROR] Port 11435 is occupied but not responding to StackSoothe health checks." -ForegroundColor Red
        Write-Host "Please close the conflicting application or run stop.bat to clear lingering processes." -ForegroundColor Red
        exit 1
    }
}

# 3. Locate Node runtime (bundled runtime first, system PATH fallback)
$PackagedNode = Join-Path $ScriptDir "runtime\node.exe"
$NodeExe = $null

if (Test-Path $PackagedNode) {
    $NodeExe = $PackagedNode
    Write-Host "`n[1/4] Using bundled standalone Node runtime." -ForegroundColor Green
} elseif (Get-Command node -ErrorAction SilentlyContinue) {
    $NodeExe = (Get-Command node).Source
    Write-Host "`n[1/4] Using system Node.js runtime: $NodeExe" -ForegroundColor Green
} else {
    Write-Host "`n[ERROR] Node.js runtime not found." -ForegroundColor Red
    Write-Host "Neither bundled runtime\node.exe nor system Node.js in PATH was detected." -ForegroundColor Red
    exit 1
}

# 4. Check Ollama service and model reachability
Write-Host "[2/4] Checking local Ollama service on 127.0.0.1:11434..." -ForegroundColor Yellow
try {
    $OllamaTags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -Method Get -TimeoutSec 2 -ErrorAction Stop
    $Models = $OllamaTags.models.name
    if ($Models -match "qwen3:1.7b") {
        Write-Host "[OK] Ollama is active with model 'qwen3:1.7b'." -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Ollama is running, but model 'qwen3:1.7b' was not found." -ForegroundColor Yellow
        Write-Host "To install model, open a terminal and run: ollama run qwen3:1.7b" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARNING] Ollama is not reachable on 127.0.0.1:11434." -ForegroundColor Yellow
    Write-Host "Live AI diagnosis requires Ollama with model 'qwen3:1.7b'." -ForegroundColor Yellow
    Write-Host "The application will launch allowing Demo Mode (rule-based) and settings review." -ForegroundColor Yellow
}

# 5. Generate secure ephemeral token and start backend service
$Token = [System.Guid]::NewGuid().ToString("N") + [System.Guid]::NewGuid().ToString("N")
$env:STACKSOOTHE_TOKEN = $Token

# Also write to service/.stacksoothe-token for file-based discovery
$TokenFile = Join-Path $ScriptDir "service\.stacksoothe-token"
try {
    [System.IO.File]::WriteAllText($TokenFile, $Token)
} catch {
    # Ignore if running in read-only environment
}

$OwnedServicePid = $null

if (-not $ServiceAlreadyRunning) {
    Write-Host "[3/4] Starting local diagnosis service in background..." -ForegroundColor Yellow
    $ServiceScript = Join-Path $ScriptDir "service\src\server.ts"
    if (-not (Test-Path $ServiceScript)) {
        Write-Host "[ERROR] Service script not found at: $ServiceScript" -ForegroundColor Red
        exit 1
    }

    $ServicePsi = New-Object System.Diagnostics.ProcessStartInfo
    $ServicePsi.FileName = $NodeExe
    $ServicePsi.Arguments = "--experimental-strip-types `"$ServiceScript`""
    $ServicePsi.WorkingDirectory = $ScriptDir
    $ServicePsi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $ServicePsi.CreateNoWindow = $true
    $ServicePsi.UseShellExecute = $false
    $ServicePsi.EnvironmentVariables["STACKSOOTHE_TOKEN"] = $Token

    $ServiceProc = [System.Diagnostics.Process]::Start($ServicePsi)
    $OwnedServicePid = $ServiceProc.Id

    # Poll /health endpoint for verified readiness (up to 15s)
    $Ready = $false
    $Attempts = 0
    while (-not $Ready -and $Attempts -lt 15) {
        Start-Sleep -Milliseconds 1000
        $Attempts++
        if ($ServiceProc.HasExited) {
            Write-Host "[ERROR] Backend service process terminated unexpectedly with exit code $($ServiceProc.ExitCode)." -ForegroundColor Red
            exit 1
        }
        try {
            $Health = Invoke-RestMethod -Uri "http://127.0.0.1:11435/health" -Method Get -TimeoutSec 1 -ErrorAction Stop
            if ($Health.status -eq "ok") {
                $Ready = $true
            }
        } catch {
            # Still initializing
        }
    }

    if (-not $Ready) {
        Write-Host "[ERROR] Timeout waiting for backend service readiness on 127.0.0.1:11435." -ForegroundColor Red
        if ($OwnedServicePid) {
            Stop-Process -Id $OwnedServicePid -Force -ErrorAction SilentlyContinue
        }
        exit 1
    }
    Write-Host "[OK] Backend diagnosis service verified ready (PID: $OwnedServicePid)." -ForegroundColor Green
} else {
    Write-Host "[3/4] Backend service already running." -ForegroundColor Green
}

# 6. Launch and monitor Flutter release desktop app
$AppExe = Join-Path $ScriptDir "app\stacksoothe.exe"
if (-not (Test-Path $AppExe)) {
    Write-Host "[ERROR] Desktop application executable not found at: $AppExe" -ForegroundColor Red
    if ($OwnedServicePid) {
        Stop-Process -Id $OwnedServicePid -Force -ErrorAction SilentlyContinue
    }
    exit 1
}

Write-Host "[4/4] Launching StackSoothe desktop interface..." -ForegroundColor Green
$AppPsi = New-Object System.Diagnostics.ProcessStartInfo
$AppPsi.FileName = $AppExe
$AppPsi.WorkingDirectory = (Join-Path $ScriptDir "app")
$AppPsi.UseShellExecute = $false
$AppPsi.EnvironmentVariables["STACKSOOTHE_TOKEN"] = $Token

$AppProc = [System.Diagnostics.Process]::Start($AppPsi)

# Monitor application process and ensure owned backend cleanup
try {
    $AppProc.WaitForExit()
} finally {
    if ($OwnedServicePid) {
        Write-Host "`nClosing owned background service (PID: $OwnedServicePid)..." -ForegroundColor Yellow
        $P = Get-Process -Id $OwnedServicePid -ErrorAction SilentlyContinue
        if ($P -and -not $P.HasExited) {
            Stop-Process -Id $OwnedServicePid -Force -ErrorAction SilentlyContinue
        }
        Write-Host "[OK] StackSoothe stopped cleanly." -ForegroundColor Green
    }
    if ($TokenFile -and (Test-Path $TokenFile)) {
        Remove-Item -Path $TokenFile -Force -ErrorAction SilentlyContinue
    }
}
