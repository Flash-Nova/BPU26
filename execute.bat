@echo off
setlocal enabledelayedexpansion
@REM chcp 65001 >nul

:: ============================================================
::  execute.bat — 按名字找源文件并编译/运行
::  用法:
::    execute.bat ^<name^>              全仓库搜索
::    execute.bat ^<name^> -d ^<dir^>    只在指定目录下搜索
::    execute.bat ?                     显示帮助
:: ============================================================

cd /d "%~dp0"
set "REPO_ROOT=%~dp0"

:: ---------- 参数解析 ----------
if "%~1"=="?" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
if "%~1"=="" goto :show_usage

set "NAME=%~1"
set "SEARCH_DIR="

if /i "%~2"=="-d" (
    if "%~3"=="" (
        echo [错误] -d 需要一个目录参数
        echo 用法: execute.bat ^<name^> -d ^<dir^>
        exit /b 1
    )
    if not exist "%~3" (
        echo [错误] 目录不存在: %~3
        exit /b 1
    )
    for %%d in ("%~3") do set "SEARCH_DIR=%%~fd"
)

goto :search_start

:show_help
echo ============================================================
echo   execute.bat — 搜索 + 编译 + 运行
echo ============================================================
echo.
echo 用法:
echo   execute.bat ^<name^>              在整个仓库搜索名为 ^<name^> 的源文件
echo   execute.bat ^<name^> -d ^<dir^>    只在指定目录下搜索
echo   execute.bat ?                     显示本帮助
echo.
echo 支持后缀: .c  .cpp  .cc  .cxx  .py
echo.
echo 行为:
echo   - 找到 1 个匹配 -^> 直接编译/运行
echo   - 找到多个匹配 -^> 列出菜单让你选
echo   - .c   使用 gcc
echo   - .cpp 使用 g++
echo   - .py  优先用仓库根目录下的 .venv, 否则用系统 python
echo.
echo 说明:
echo   C/C++ 编译时加 -fexec-charset=GBK, 让源文件 UTF-8 中的
echo   字符串常量在 exe 里变成 GBK 字节, 直接适配 cmd 936。
echo.
echo 示例:
echo   execute.bat first
echo   execute.bat hw -d date\20260929-c
echo.
pause
exit /b 0

:show_usage
echo 用法: execute.bat ^<name^> [ -d ^<dir^> ]
echo 帮助: execute.bat ?
pause
exit /b 1

:: ---------- 搜索 ----------
:search_start
set "TMPFILE=%TEMP%\execute_search_%RANDOM%%RANDOM%.txt"

if defined SEARCH_DIR (
    echo [信息] 搜索范围: !SEARCH_DIR!
    powershell -NoProfile -Command "Get-ChildItem -Path '!SEARCH_DIR!' -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -in @('%NAME%.c','%NAME%.cpp','%NAME%.cc','%NAME%.cxx','%NAME%.py') -and $_.FullName -notlike '*\.git\*' -and $_.FullName -notlike '*\.venv\*' } | Select-Object -ExpandProperty FullName" > "%TMPFILE%" 2>nul
) else (
    powershell -NoProfile -Command "Get-ChildItem -Path '%REPO_ROOT%' -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -in @('%NAME%.c','%NAME%.cpp','%NAME%.cc','%NAME%.cxx','%NAME%.py') -and $_.FullName -notlike '*\.git\*' -and $_.FullName -notlike '*\.venv\*' } | Select-Object -ExpandProperty FullName" > "%TMPFILE%" 2>nul
)

set "COUNT=0"
for /f "usebackq delims=" %%f in ("%TMPFILE%") do (
    set /a COUNT+=1
    set "FILE_!COUNT!=%%f"
)
del "%TMPFILE%" >nul 2>&1

if %COUNT%==0 (
    echo [错误] 未找到名为 %NAME% 的源文件 ^(.c .cpp .cc .cxx .py^)
    exit /b 1
)

if %COUNT%==1 (
    set "TARGET=!FILE_1!"
    goto :run
)

echo.
echo 找到 %COUNT% 个匹配:
echo.
for /l %%i in (1,1,%COUNT%) do call :format_line %%i "!FILE_%%i!"
echo.

:ask
set "CHOICE="
set /p "CHOICE=请输入序号 (1-%COUNT%): "
echo !CHOICE!| findstr /r "^[1-9][0-9]*$" >nul
if errorlevel 1 goto :ask
if !CHOICE! LSS 1 goto :ask
if !CHOICE! GTR %COUNT% goto :ask
set "TARGET=!FILE_%CHOICE%!"

:run
echo.
echo [INFO] 选中: !TARGET!

for %%f in ("!TARGET!") do (
    set "EXT=%%~xf"
    set "DIR=%%~dpf"
    set "BASE=%%~nf"
)

if /i "!EXT!"==".c"   goto :run_c
if /i "!EXT!"==".cpp" goto :run_cpp
if /i "!EXT!"==".cc"  goto :run_cpp
if /i "!EXT!"==".cxx" goto :run_cpp
if /i "!EXT!"==".py"  goto :run_py
echo [错误] 不支持的扩展名: !EXT!
exit /b 1

:run_c
echo [INFO] gcc 编译...
gcc -fexec-charset=GBK "!TARGET!" -o "!DIR!!BASE!.exe"
if errorlevel 1 (
    echo.
    echo [警告] -fexec-charset 不被支持, 尝试不带该参数重新编译...
    gcc "!TARGET!" -o "!DIR!!BASE!.exe"
    if errorlevel 1 ( echo [错误] 编译失败 & exit /b 1 )
)
echo [INFO] 运行 !DIR!!BASE!.exe
echo ------------------------------------------------------------
"!DIR!!BASE!.exe"
set "RC=!ERRORLEVEL!"
echo.
echo ------------------------------------------------------------
echo [INFO] 退出码: !RC!
exit /b !RC!

:run_cpp
echo [INFO] g++ 编译...
g++ -fexec-charset=GBK "!TARGET!" -o "!DIR!!BASE!.exe"
if errorlevel 1 (
    echo.
    echo [警告] -fexec-charset 不被支持, 尝试不带该参数重新编译...
    g++ "!TARGET!" -o "!DIR!!BASE!.exe"
    if errorlevel 1 ( echo [错误] 编译失败 & exit /b 1 )
)
echo [INFO] 运行 !DIR!!BASE!.exe
echo ------------------------------------------------------------
"!DIR!!BASE!.exe"
set "RC=!ERRORLEVEL!"
echo.
echo ------------------------------------------------------------
echo [INFO] 退出码: !RC!
exit /b !RC!

:run_py
set "PYTHON="
if exist "%REPO_ROOT%.venv\Scripts\python.exe" (
    set "PYTHON=%REPO_ROOT%.venv\Scripts\python.exe"
    echo [INFO] 使用 venv: %REPO_ROOT%.venv
) else (
    where python >nul 2>&1
    if errorlevel 1 (
        echo [错误] 未找到 python，也没有 %REPO_ROOT%.venv
        exit /b 1
    )
    set "PYTHON=python"
    echo [INFO] 使用系统 python ^(未找到 .venv^)
)
echo [INFO] 运行 !TARGET!
echo ------------------------------------------------------------
"!PYTHON!" "!TARGET!"
set "RC=!ERRORLEVEL!"
echo.
echo ------------------------------------------------------------
echo [INFO] 退出码: !RC!
exit /b !RC!

:: ---------- 子程序：格式化一行菜单 ----------
:format_line
set "IDX=%~1"
set "FPATH=%~2"

for %%f in ("%FPATH%") do (
    set "FDIR=%%~dpf"
    set "FNAME=%%~nxf"
)
set "FDIR=!FDIR:~0,-1!"
for %%d in ("!FDIR!") do set "PARENT=%%~nxd"

set "DATE_PART=!PARENT:~0,8!"
set "SUFFIX_PART=!PARENT:~9!"

set "Y=!DATE_PART:~0,4!"
set "M=!DATE_PART:~4,2!"
set "D=!DATE_PART:~6,2!"

set "SUFFIX_DISPLAY="
if /i "!SUFFIX_PART!"=="c"     set "SUFFIX_DISPLAY=C"
if /i "!SUFFIX_PART!"=="ai"    set "SUFFIX_DISPLAY=AI"
if /i "!SUFFIX_PART!"=="other" set "SUFFIX_DISPLAY=Other"
if not defined SUFFIX_DISPLAY  set "SUFFIX_DISPLAY=!SUFFIX_PART!"

echo   !IDX!^|!Y!-!M!-!D!^|!SUFFIX_DISPLAY!^|!FNAME!
exit /b 0