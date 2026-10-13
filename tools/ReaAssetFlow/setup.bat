@echo off
chcp 65001 >nul
setlocal

echo ============================================
echo   ReaAssetFlow - Environment Setup
echo ============================================
echo.

where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not detected.
    echo Please install Python 3.8+ from https://www.python.org/downloads/
    echo Remember to check "Add Python to PATH" during installation.
    echo.
    pause
    exit /b 1
)

echo [1/2] Checking Python version...
python --version
echo.

echo [2/2] Installing base dependencies...
python -m pip install --upgrade pip
python -m pip install -r "%~dp0requirements.txt"
if errorlevel 1 (
    echo [ERROR] Failed to install dependencies.
    pause
    exit /b 1
)
echo.

echo ============================================
echo   Setup complete.
echo ============================================
echo.
echo Next steps:
echo   1. Open Wwise with WAAPI enabled (default port 8080)
echo   2. In Reaper, ReaScript: Load ReaAssetFlow.lua
echo   3. In the panel, use Browse Project to pick your .wproj
echo   4. Optional LLM features: run setup-llm.bat
echo.
pause
