@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"
rem Tira o bloqueio de "arquivo baixado da Internet" do kit (evita o Aviso de seguranca)
powershell.exe -NoProfile -Command "Get-ChildItem -LiteralPath '%~dp0' -File | Unblock-File"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar.ps1"
echo.
pause
