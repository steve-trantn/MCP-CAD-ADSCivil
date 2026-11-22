@echo off
chcp 65001 >nul
cd /d "%~dp0"
if not defined GEMINI_API_KEY if not exist "%~dp0.env" (
  echo Chua co GEMINI_API_KEY. Lay key tai https://aistudio.google.com/apikey
  echo roi tao file "%~dp0.env" voi dong: GEMINI_API_KEY=key_cua_ban
  pause
  exit /b 1
)
gemini
