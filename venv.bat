@echo off

:: ============================================================
::  venv.bat - 虚拟环境管理
:: ============================================================

:: ---------- quit 放在 setlocal 之前，deactivate 才能生效 ----------
if /i "%~1"=="quit" goto :mode_quit

setlocal

set "REPO_ROOT=%~dp0"
set "VENV_DIR=%REPO_ROOT%.venv"
set "VENV_SCRIPTS=%VENV_DIR%\Scripts"
set "REQ_FILE=%REPO_ROOT%requirements.txt"

if "%~1"=="" goto :show_help
if "%~1"=="?" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="init" goto :mode_init
if /i "%~1"=="start" goto :mode_init
if /i "%~1"=="req" goto :mode_req

if not exist "%VENV_SCRIPTS%\python.exe" (
    echo [错误] 未找到 .venv
    echo        请先执行: venv.bat init
    exit /b 1
)

:: 命令代理: 临时把 venv\Scripts 放 PATH 最前
set "PATH=%VENV_SCRIPTS%;%PATH%"
%*

exit /b %ERRORLEVEL%

:show_help
echo ============================================================
echo   venv.bat - 虚拟环境管理
echo ============================================================
echo.
echo 用法:
echo   venv.bat init              创建 .venv（若已存在则跳过）
echo   venv.bat quit              退出当前 shell 的 venv 激活
echo   venv.bat req save          导出依赖到 requirements.txt
echo   venv.bat req load          从 requirements.txt 安装依赖
echo   venv.bat pip install xxx   在 venv 里跑 pip
echo   venv.bat python xxx.py     在 venv 里跑 python
echo   venv.bat ?                 显示本帮助
echo.
pause
exit /b 0

:mode_init
if exist "%VENV_SCRIPTS%\python.exe" (
    echo [信息] .venv 已存在, 跳过创建。
    exit /b 0
)
echo [信息] 正在创建 .venv...
py -m venv "%VENV_DIR%"
if errorlevel 1 (
    echo [错误] 创建 .venv 失败。
    exit /b 1
)
echo [OK] .venv 创建完成。
exit /b 0

:mode_req
if not exist "%VENV_SCRIPTS%\python.exe" (
    echo [错误] 未找到 .venv
    echo        请先执行: venv.bat init
    exit /b 1
)
set "PATH=%VENV_SCRIPTS%;%PATH%"

if /i "%~2"=="save" (
    python -m pip freeze > "%REQ_FILE%"
    if errorlevel 1 (
        echo [错误] 导出失败。
        exit /b 1
    )
    echo [OK] 已导出: requirements.txt
    exit /b 0
)

if /i "%~2"=="load" (
    if not exist "%REQ_FILE%" (
        echo [错误] 未找到 requirements.txt
        exit /b 1
    )
    pip install -r "%REQ_FILE%"
    if errorlevel 1 (
        echo [错误] 安装依赖失败。
        exit /b 1
    )
    echo [OK] 依赖安装完成。
    exit /b 0
)

echo [错误] req 需要 save 或 load 参数
echo 用法: venv.bat req save ^| venv.bat req load
exit /b 1

:mode_quit
set "VENV_SCRIPTS=%~dp0.venv\Scripts"
if not exist "%VENV_SCRIPTS%\deactivate.bat" (
    echo [错误] 未找到 .venv\Scripts\deactivate.bat
    exit /b 1
)
call "%VENV_SCRIPTS%\deactivate.bat"
echo [OK] 已退出 venv。
exit /b 0