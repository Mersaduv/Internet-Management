@echo off
setlocal
cd /d "%~dp0.."

REM یک‌جا بیلد Windows + Android (+ Setup با آرگومان)
REM مثال:
REM   tools\build_all.bat
REM   tools\build_all.bat -Installer
REM   tools\build_all.bat -WindowsOnly
REM   tools\build_all.bat -AndroidOnly

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_all.ps1" %*
set ERR=%ERRORLEVEL%
if %ERR% neq 0 (
  echo.
  echo Build failed with exit code %ERR%
  pause
  exit /b %ERR%
)
echo.
pause
exit /b 0
