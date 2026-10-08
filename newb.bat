@echo off
setlocal enabledelayedexpansion
@REM chcp 65001 >nul

:: ============================================================
::  New Branch — newb.bat
::  用法:
::    newb.bat                   按日期+课型创建分支
::    newb.bat -custom ^<name^>   创建自定义名字的分支
::    newb.bat ?                 显示帮助
:: ============================================================

cd /d "%~dp0"

:: ---------- 参数解析 ----------
if "%~1"=="?" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-custom" goto :mode_custom
if "%~1"=="" goto :mode_default
echo [错误] 未知参数: %~1
echo.
goto :show_help

:show_help
echo ============================================================
echo   newb.bat — 创建临时分支 + 同名目录
echo ============================================================
echo.
echo 用法:
echo   newb.bat                   按当前日期+课型创建分支
echo                              周二/四 08-10 点  ^-^> yyyyMMdd-c
echo                              周三   08-10 点  ^-^> yyyyMMdd-ai
echo                              其他时段        ^-^> yyyyMMdd-other
echo.
echo   newb.bat -custom ^<name^>   创建自定义名字的分支
echo                              name 只允许字母、数字、横杠 [a-zA-Z0-9-]
echo.
echo   newb.bat ?                 显示本帮助
echo.
echo 说明:
echo   - 创建前会先切到 dev 并同步 origin/dev
echo   - 分支建好后自动创建目录 date\^<分支名^>
echo   - 若当前在 dev 上有脏改动, 会随新分支一起带走
echo.
pause
exit /b 0

:: ---------- 自定义模式 ----------
:mode_custom
if "%~2"=="" (
    echo [错误] -custom 需要一个分支名参数
    echo 用法: newb.bat -custom ^<name^>
    exit /b 1
)
set "CUSTOM_NAME=%~2"

:: 严格校验: 只允许 ASCII 字母数字横杠
powershell -NoProfile -Command "if ('!CUSTOM_NAME!' -match '^[a-zA-Z0-9-]+$') { exit 0 } else { exit 1 }"
if errorlevel 1 (
    echo.
    echo [错误] 分支名只允许字母、数字、横杠
    echo        你输入的是: !CUSTOM_NAME!
    echo.
    exit /b 1
)

set "BRANCH=!CUSTOM_NAME!"
set "MODE=custom"
goto :after_param

:: ---------- 默认模式 ----------
:mode_default
set "MODE=default"
goto :after_param

:: ---------- 公共流程 ----------
:after_param
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [错误] 当前目录不是 Git 仓库: %CD%
    exit /b 1
)

:: 若当前不在 dev, 先切到 dev
set "CURBR="
for /f "delims=" %%b in ('git branch --show-current') do set "CURBR=%%b"

if /i not "!CURBR!"=="dev" (
    echo [信息] 切换到 dev 分支...
    git checkout dev
    if errorlevel 1 (
        echo [错误] 无法切换到 dev 分支。
        exit /b 1
    )
) else (
    set "DIRTY="
    for /f "delims=" %%u in ('git status --porcelain') do set "DIRTY=1"
    if defined DIRTY (
        echo.
        echo [提示] dev 上存在未提交的改动, 将随新分支一起带过去:
        git status --short
        echo.
    )
)

:: 同步 dev
echo [信息] 从 origin 同步 dev...
git pull --ff-only origin dev 2>nul
if errorlevel 1 (
    echo [警告] 无法快进同步远程 dev ^(可能无网络或本地 dev 分叉^)
    echo        继续基于本地 dev 开新分支
)

:: 自定义模式: BRANCH 已就绪, 直接开
if /i "!MODE!"=="custom" (
    echo ============================================================
    echo   自定义分支: !BRANCH!
    echo ============================================================
    goto :create_branch
)

:: 默认模式: 读日期, 算后缀 (用临时文件避免 for /f 引号嵌套)
set "DATE_TMP=%TEMP%\newb_date_%RANDOM%.txt"
powershell -NoProfile -Command "$d=Get-Date; Write-Output ($d.ToString('yyyyMMdd') + ' ' + $d.Hour + ' ' + [int]$d.DayOfWeek)" > "%DATE_TMP%" 2>nul

set "TODAY="
set "HOUR="
set "DOW="
for /f "tokens=1,2,3" %%a in (%DATE_TMP%) do (
    set "TODAY=%%a"
    set "HOUR=%%b"
    set "DOW=%%c"
)
del "%DATE_TMP%" 2>nul

if not defined TODAY (
    echo [错误] 无法获取本机日期。
    exit /b 1
)

:: 校验读到的值确实像数字
echo !TODAY!| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo [错误] 日期格式异常: TODAY=!TODAY!
    echo        PowerShell 可能返回了意外内容, 请检查系统环境。
    exit /b 1
)

set "SUFFIX=-other"
if "%DOW%"=="2" if %HOUR% GEQ 8 if %HOUR% LSS 10 set "SUFFIX=-c"
if "%DOW%"=="4" if %HOUR% GEQ 8 if %HOUR% LSS 10 set "SUFFIX=-c"
if "%DOW%"=="3" if %HOUR% GEQ 8 if %HOUR% LSS 10 set "SUFFIX=-ai"
set "BRANCH=%TODAY%%SUFFIX%"

echo ============================================================
echo   日期: %TODAY%   小时: %HOUR%   星期: %DOW%
echo   目标分支: %BRANCH%
echo ============================================================

:create_branch
git show-ref --verify --quiet "refs/heads/!BRANCH!"
if not errorlevel 1 (
    echo [提示] 分支已存在，直接切换。
    git checkout "!BRANCH!"
    if errorlevel 1 (
        echo [错误] 切换失败, 可能有未提交改动与新分支冲突。
        exit /b 1
    )
) else (
    git checkout -b "!BRANCH!"
    if errorlevel 1 (
        echo [错误] 创建分支失败, 可能有未提交改动与新分支冲突。
        exit /b 1
    )
)

set "BRANCH_DIR=date\!BRANCH!"
if not exist "!BRANCH_DIR!" (
    mkdir "!BRANCH_DIR!"
    echo [OK] 已创建目录: !BRANCH_DIR!
) else (
    echo [提示] 目录已存在: !BRANCH_DIR!
)

echo.
echo [完成] 当前分支:
git branch --show-current
echo.

endlocal
exit /b 0