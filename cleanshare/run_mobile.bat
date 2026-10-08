@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0tool\run_mobile_web.ps1" %*
