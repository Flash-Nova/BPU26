@echo off
setlocal enabledelayedexpansion
@REM chcp 65001 >nul

:: ============================================================
::  execute.bat — 搜索 + 编译 + 运行 (带时间戳缓存)
::  用法:
::    execute.bat <name>               全仓库搜索
::    execute.bat <name> -d <dir>      只在指定目录下搜索
::    execute.bat <name> -f            强制重新编译
::    execute.bat ?                    显示帮助
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
set "FORCE_BUILD="

shift
:parse_args
if "%~1"=="" goto :parse_done
if /i "%~1"=="-d" (
    if "%~2"=="" (
        echo [错误] -d 需要一个目录参数
        exit /b 1
    )
    if not exist "%~2" (
        echo [错误] 目录不存在: %~2
        exit /b 1
    )
    for %%d in ("%~2") do set "SEARCH_DIR=%%~fd"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="-f" (
    set "FORCE_BUILD=1"
    shift
    goto :parse_args
)
echo [错误] 未知参数: %~1
exit /b 1

:parse_done
goto :search_start

:show_help
echo ============================================================
echo   execute.bat — 搜索 + 编译 + 运行
echo ============================================================
echo.
echo 用法:
echo   execute.bat ^<name^>              在整个仓库搜索 ^<name^> 的源文件
echo   execute.bat ^<name^> -d ^<dir^>    只在指定目录下搜索
echo   execute.bat ^<name^> -f            强制重新编译
echo   execute.bat ?                     显示本帮助
echo.
echo 支持后缀: .c  .cpp  .cc  .cxx  .py
echo.
echo 行为:
echo   - exe 比源文件新  -^> 跳过编译, 直接运行
echo   - exe 比源文件旧  -^> 重新编译再运行
echo   - exe 不存在      -^> 直接编译再运行
echo.
pause
exit /b 0

:show_usage
echo 用法: execute.bat ^<name^> [ -d ^<dir^> ] [ -f ]
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

:: ---------- C ----------
:run_c
set "SRC=!TARGET!"
set "EXE=!DIR!!BASE!.exe"
set "NEED_BUILD=1"

if exist "!EXE!" if not defined FORCE_BUILD (
    powershell -NoProfile -Command "if ((Get-Item -LiteralPath '!SRC!').LastWriteTime -le (Get-Item -LiteralPath '!EXE!').LastWriteTime) { exit 0 } else { exit 1 }"
    if not errorlevel 1 (
        set "NEED_BUILD=0"
        echo [INFO] 已是最新, 跳过编译。
    )
)

if "!NEED_BUILD!"=="1" (
    echo [INFO] gcc 编译...
    gcc -fexec-charset=GBK "!SRC!" -o "!EXE!"
    if errorlevel 1 (
        echo.
        echo [警告] -fexec-charset 不被支持, 尝试不带该参数重新编译...
        gcc "!SRC!" -o "!EXE!"
        if errorlevel 1 ( echo [错误] 编译失败 & exit /b 1 )
    )
)

echo [INFO] 运行 !EXE!
echo ------------------------------------------------------------
"!EXE!"
set "RC=!ERRORLEVEL!"
echo.
echo ------------------------------------------------------------
echo [INFO] 退出码: !RC!
exit /b !RC!

:: ---------- C++ ----------
:run_cpp
set "SRC=!TARGET!"
set "EXE=!DIR!!BASE!.exe"
set "NEED_BUILD=1"

if exist "!EXE!" if not defined FORCE_BUILD (
    powershell -NoProfile -Command "if ((Get-Item -LiteralPath '!SRC!').LastWriteTime -le (Get-Item -LiteralPath '!EXE!').LastWriteTime) { exit 0 } else { exit 1 }"
    if not errorlevel 1 (
        set "NEED_BUILD=0"
        echo [INFO] 已是最新, 跳过编译。
    )
)

if "!NEED_BUILD!"=="1" (
    echo [INFO] g++ 编译...
    g++ -fexec-charset=GBK "!SRC!" -o "!EXE!"
    if errorlevel 1 (
        echo.
        echo [警告] -fexec-charset 不被支持, 尝试不带该参数重新编译...
        g++ "!SRC!" -o "!EXE!"
        if errorlevel 1 ( echo [错误] 编译失败 & exit /b 1 )
    )
)

echo [INFO] 运行 !EXE!
echo ------------------------------------------------------------
"!EXE!"
set "RC=!ERRORLEVEL!"
echo.
echo ------------------------------------------------------------
echo [INFO] 退出码: !RC!
exit /b !RC!

:: ---------- Python ----------
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
:: 把仓库根目录加入 PYTHONPATH，让 ai_method 随处可用
set "PYTHONPATH=%REPO_ROOT%"
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