@echo off
chcp 65001 >nul
setlocal

echo ============================================
echo   ReaAssetFlow - LLM Optional Setup
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

echo [2/2] Installing optional LLM dependencies...
python -m pip install --upgrade pip
pushd "%~dp0"
python -m pip install ".[llm]"
popd
if errorlevel 1 (
    echo [ERROR] Failed to install optional LLM dependencies.
    pause
    exit /b 1
)
echo.

echo ============================================
echo   Optional LLM setup complete.
echo ============================================
echo.
echo Next steps for LLM features:
echo   1. Install Ollama from https://ollama.com/
echo   2. Start local service: ollama serve
echo   3. Pull your model, for example: ollama pull qwen2.5vl:7b
echo.
pause
