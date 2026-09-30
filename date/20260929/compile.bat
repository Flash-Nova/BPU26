@echo off
setlocal

if "%~1"=="" (
    echo Usage: %~nx0 ^<source.c^>
    exit /b 1
)

if not exist "%~1" (
    echo [ERROR] File not found: %~1
    exit /b 1
)

gcc "%~1" -o "%~dpn1.exe"

if errorlevel 1 (
    echo [ERROR] Compile failed.
    exit /b 1
)

echo [OK] %~dpn1.exe
endlocal