@echo off
setlocal enabledelayedexpansion
title Stop StackSoothe

echo Stopping StackSoothe application and background service...

REM Kill Flutter application
taskkill /f /im stacksoothe.exe >nul 2>nul
if %errorlevel% equ 0 (
    echo [OK] Terminated stacksoothe.exe
) else (
    echo [INFO] stacksoothe.exe was not running.
)

REM Find and terminate Node service listening on port 11435
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":11435" ^| findstr "LISTENING"') do (
    taskkill /f /pid %%a >nul 2>nul
    if !errorlevel! equ 0 (
        echo [OK] Terminated service process PID %%a listening on port 11435
    )
)

echo.
echo StackSoothe stopped successfully.
timeout /t 2 >nul
