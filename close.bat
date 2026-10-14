@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0close.ps1" %*
exit /b %ERRORLEVEL%