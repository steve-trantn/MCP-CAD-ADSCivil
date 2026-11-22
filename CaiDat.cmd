@echo off
title ADSCivil MCP - Cai dat
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\installer.ps1" %*
echo.
pause
