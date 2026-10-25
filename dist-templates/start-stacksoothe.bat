@echo off
setlocal
title StackSoothe

REM Switch to script directory, handling spaces and drive switches
cd /d "%~dp0"

REM Launch PowerShell orchestrator
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch.ps1"
set LAUNCHER_EXIT=%errorlevel%

if %LAUNCHER_EXIT% neq 0 (
    echo.
    echo ========================================================
    echo   StackSoothe encountered an error during launch.
    echo   Exit code: %LAUNCHER_EXIT%
    echo ========================================================
    echo.
    pause
)

exit /b %LAUNCHER_EXIT%
