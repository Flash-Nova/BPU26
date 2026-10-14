@echo off
:: 注意：本脚本不使用 setlocal
:: 因为 call activate.bat 设置的环境变量要能传回父 shell

if "%~1"=="?" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="start" goto :mode_start
if /i "%~1"=="quit" goto :mode_quit
if "%~1"=="" goto :show_help

echo [错误] 未知参数: %~1
echo.
goto :show_help

:show_help
echo ============================================================
echo   venv.bat — 管理 Python 虚拟环境
echo ============================================================
echo.
echo 用法:
echo   venv.bat start   创建（若不存在）并激活 .venv
echo   venv.bat quit    退出当前 .venv
echo   venv.bat ?       显示本帮助
echo.
echo 重要提示:
echo   想要在当前终端里真正激活，必须用 call 调用:
echo     call venv.bat start
echo   直接双击或在 cmd 里 "venv.bat start" 的话，
echo   激活只会在子进程里生效，本终端看不到 (.venv) 前缀。
echo.
pause
exit /b 0

:mode_start
if exist ".venv\Scripts\activate.bat" (
    echo [信息] 已存在 .venv, 直接激活...
) else (
    echo [信息] 未找到 .venv, 正在创建...
    py -m venv .venv
    if errorlevel 1 (
        echo [错误] 创建 .venv 失败。
        exit /b 1
    )
    echo [OK] .venv 创建完成。
)

call ".venv\Scripts\activate.bat"
if errorlevel 1 (
    echo [错误] 激活 .venv 失败。
    exit /b 1
)
echo [OK] 已激活 .venv。
exit /b 0

:mode_quit
if not exist ".venv\Scripts\deactivate.bat" (
    echo [错误] 未找到 .venv，无法退出。
    exit /b 1
)
call ".venv\Scripts\deactivate.bat"
echo [OK] 已退出 .venv。
exit /b 0