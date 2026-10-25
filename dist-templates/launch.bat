@echo off
setlocal enabledelayedexpansion
title StackSoothe Launcher

echo ========================================================
echo   StackSoothe -- Local Flutter ^& Dart Debugging Assistant
echo ========================================================
echo.

REM 1. Check Node.js
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Node.js is required but was not found in PATH.
    echo Please install Node.js v24 or later from https://nodejs.org/
    echo.
    pause
    exit /b 1
)

REM 2. Check Ollama reachability (graceful warning, not hard exit)
echo [1/3] Checking local Ollama service on 127.0.0.1:11434...
curl.exe -s -o nul http://127.0.0.1:11434/api/tags
if %errorlevel% neq 0 (
    echo [WARNING] Ollama does not appear to be running on 127.0.0.1:11434.
    echo StackSoothe requires Ollama with model 'qwen3:1.7b' for live AI diagnosis.
    echo You can start Ollama in another terminal with: ollama run qwen3:1.7b
    echo The desktop application will open and allow rule-based examples or settings inspection.
    echo.
) else (
    echo [OK] Ollama is reachable.
)

REM 3. Start local Node loopback service
echo [2/3] Starting local StackSoothe diagnosis service on 127.0.0.1:11435...

REM Check if service is already running
curl.exe -s -o nul http://127.0.0.1:11435/health
if %errorlevel% equ 0 (
    echo [INFO] Service is already running on 127.0.0.1:11435.
) else (
    start "StackSoothe Service" /b node --experimental-strip-types service\src\server.ts
    REM Wait for service health check
    set /a attempts=0
    :health_loop
    timeout /t 1 /nobreak >nul
    curl.exe -s -o nul http://127.0.0.1:11435/health
    if %errorlevel% neq 0 (
        set /a attempts+=1
        if !attempts! geq 10 (
            echo [ERROR] Failed to start StackSoothe service within 10 seconds.
            echo Please check console output or inspect service logs.
            pause
            exit /b 1
        )
        goto health_loop
    )
    echo [OK] Diagnosis service is healthy.
)

REM 4. Launch Flutter Windows desktop app
echo [3/3] Launching StackSoothe desktop application...
cd app
start "" stacksoothe.exe
cd ..

echo.
echo ========================================================
echo   StackSoothe is now running!
echo   To cleanly shut down, run stop.bat
echo ========================================================
echo.
