@echo off
chcp 65001 >nul

if defined GIT_ASKPASS_MARKER (
    py "%~dp0close.py" --askpass "%~1"
    exit /b %ERRORLEVEL%
)
py "%~dp0close.py" %*

exit /b %ERRORLEVEL%