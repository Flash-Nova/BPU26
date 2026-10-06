@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

:: ============================================================
::  start.bat — 按名字找源文件并编译/运行
::  用法:  start.bat ^<名字(不带后缀)^>
::  例:    start.bat first
:: ============================================================

cd /d "%~dp0"
set "REPO_ROOT=%~dp0"

if "%~1"=="" (
    echo 用法: %~nx0 ^<文件名^(不带后缀^)^>
    echo 例:   %~nx0 first
    pause
    exit /b 1
)

set "NAME=%~1"

:: ---------- 搜索 ----------
set "TMPFILE=%TEMP%\start_search_%RANDOM%%RANDOM%.txt"
powershell -NoProfile -Command "Get-ChildItem -Path '%REPO_ROOT%' -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -in @('%NAME%.c','%NAME%.cpp','%NAME%.cc','%NAME%.cxx','%NAME%.py') -and $_.FullName -notlike '*\.git\*' -and $_.FullName -notlike '*\.venv\*' } | Select-Object -ExpandProperty FullName" > "%TMPFILE%" 2>nul

set "COUNT=0"
for /f "usebackq delims=" %%f in ("%TMPFILE%") do (
    set /a COUNT+=1
    set "FILE_!COUNT!=%%f"
)
del "%TMPFILE%" >nul 2>&1

if %COUNT%==0 (
    echo [错误] 未找到名为 %NAME% 的源文件 ^(.c .cpp .cc .cxx .py^)
    pause
    exit /b 1
)

if %COUNT%==1 (
    set "TARGET=!FILE_1!"
    goto :run
)

:: ---------- 多个：列菜单 ----------
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
pause
exit /b 1

:run_c
echo [INFO] gcc 编译...
gcc "!TARGET!" -o "!DIR!!BASE!.exe"
if errorlevel 1 ( echo [错误] 编译失败 & pause & exit /b 1 )
echo [INFO] 运行 !DIR!!BASE!.exe
echo ------------------------------------------------------------
"!DIR!!BASE!.exe"
set "RC=!ERRORLEVEL!"
echo ------------------------------------------------------------
echo [INFO] 退出码: !RC!
pause
exit /b !RC!

:run_cpp
echo [INFO] g++ 编译...
g++ "!TARGET!" -o "!DIR!!BASE!.exe"
if errorlevel 1 ( echo [错误] 编译失败 & pause & exit /b 1 )
echo [INFO] 运行 !DIR!!BASE!.exe
echo ------------------------------------------------------------
"!DIR!!BASE!.exe"
set "RC=!ERRORLEVEL!"
echo ------------------------------------------------------------
echo [INFO] 退出码: !RC!
pause
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
        pause
        exit /b 1
    )
    set "PYTHON=python"
    echo [INFO] 使用系统 python ^(未找到 .venv^)
)
echo [INFO] 运行 !TARGET!
echo ------------------------------------------------------------
"!PYTHON!" "!TARGET!"
set "RC=!ERRORLEVEL!"
echo ------------------------------------------------------------
echo [INFO] 退出码: !RC!
pause
exit /b !RC!

:: ---------- 子程序：格式化一行菜单 ----------
:format_line
:: %1 = 序号, %2 = 完整路径
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

echo   !IDX!丨!Y!-!M!-!D!丨!SUFFIX_DISPLAY!丨!FNAME!
exit /b 0