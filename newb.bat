@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

:: ============================================================
::  New Branch — newb.bat — 建分支 + 建同名文件夹并切过去
::  分支命名: yyyyMMdd + (-c | -ai | -other)
::
::  dev 上若有未提交改动: 直接带入新分支, 不做 commit/stash
::  (Git 默认行为, 新分支建好后这些改动就落在新分支工作区)
:: ============================================================

cd /d "%~dp0"

:: ---------- 0. 必须是 Git 仓库 ----------
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [错误] 当前目录不是 Git 仓库: %CD%
    pause
    exit /b 1
)

:: ---------- 0.5 若在 dev 且有脏改动, 提示一下(不阻塞) ----------
set "CURBR="
for /f "delims=" %%b in ('git branch --show-current') do set "CURBR=%%b"

if /i "!CURBR!"=="dev" (
    set "DIRTY="
    for /f "delims=" %%u in ('git status --porcelain') do set "DIRTY=1"
    if defined DIRTY (
        echo.
        echo [提示] dev 上存在未提交的改动, 将随新分支一起带过去:
        git status --short
        echo.
    )
)

:: ---------- 1. 读取本机日期 / 小时 / 星期 ----------
set "TODAY="
set "HOUR="
set "DOW="
for /f "tokens=1,2,3" %%a in ('powershell -NoProfile -Command "$d=Get-Date; Write-Output ($d.ToString(''yyyyMMdd'') + '' '' + [int]$d.Hour + '' '' + [int]$d.DayOfWeek)"') do (
    set "TODAY=%%a"
    set "HOUR=%%b"
    set "DOW=%%c"
)
if not defined TODAY (
    echo [错误] 无法获取本机日期。
    pause
    exit /b 1
)

:: ---------- 2. 计算后缀 ----------
:: DayOfWeek: 周日=0 周一=1 周二=2 周三=3 周四=4 周五=5 周六=6
set "SUFFIX=-other"
if "%DOW%"=="2" if %HOUR% GEQ 8 if %HOUR% LSS 10 set "SUFFIX=-c"
if "%DOW%"=="4" if %HOUR% GEQ 8 if %HOUR% LSS 10 set "SUFFIX=-c"
if "%DOW%"=="3" if %HOUR% GEQ 8 if %HOUR% LSS 10 set "SUFFIX=-ai"

set "BRANCH=%TODAY%%SUFFIX%"

echo ============================================================
echo   日期: %TODAY%   小时: %HOUR%   星期: %DOW%
echo   目标分支: %BRANCH%
echo ============================================================

:: ---------- 3. 建分支 / 切分支 ----------
git show-ref --verify --quiet "refs/heads/%BRANCH%"
if not errorlevel 1 (
    echo [提示] 分支已存在，直接切换。
    git checkout "%BRANCH%"
    if errorlevel 1 (
        echo.
        echo [错误] 切换失败, 很可能 dev 上的未提交改动与新分支冲突。
        echo        请先处理冲突文件后再试。
        pause
        exit /b 1
    )
) else (
    git checkout -b "%BRANCH%"
    if errorlevel 1 (
        echo.
        echo [错误] 创建分支失败, 很可能 dev 上的未提交改动与新分支冲突。
        echo        请先处理冲突文件后再试。
        pause
        exit /b 1
    )
)

:: ---------- 4. 创建同名文件夹 ----------
set "BRANCH_DIR=date\%BRANCH%"
if not exist "%BRANCH_DIR%" (
    mkdir "%BRANCH_DIR%"
    echo [OK] 已创建目录: %BRANCH_DIR%
) else (
    echo [提示] 目录已存在: %BRANCH_DIR%
)

echo.
echo [完成] 当前分支:
git branch --show-current
echo.

pause
endlocal