@echo off
setlocal enabledelayedexpansion
@REM chcp 65001 >nul

:: ============================================================
::  close.bat — 关闭当前临时分支
::  用法:
::    close.bat               merge 到 dev + push + 删除分支
::    close.bat -nomerge      直接删除分支, 未提交改动继承到 dev
::    close.bat ?             显示帮助
:: ============================================================

cd /d "%~dp0"

:: ---------- 参数解析 ----------
if "%~1"=="?" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-nomerge" goto :mode_no_merge
if "%~1"=="" goto :mode_default
echo [错误] 未知参数: %~1
echo.
goto :show_help

:show_help
echo ============================================================
echo   close.bat - 关闭当前临时分支
echo ============================================================
echo.
echo 用法:
echo   close.bat              默认: 合并到 dev + 推送 + 删除分支
echo   close.bat -nomerge     危险: 直接删除分支, 未提交改动继承到 dev
echo   close.bat ?            显示本帮助
echo.
echo 默认流程:
echo   1. 检查工作区必须干净
echo   2. 隐藏输入 PAT (仅存内存 120 秒)
echo   3. 切到 dev, pull rebase 同步
echo   4. merge 临时分支到 dev
echo   5. push dev 到 origin
echo   6. 删除本地临时分支
echo   7. 主动清空内存中的 PAT
echo.
echo -nomerge 说明:
echo   - 直接删除当前分支, 该分支上未提交到 commit 的改动会丢失
echo   - 工作区里未提交的改动会继承到 dev
echo   - 需要输入 DELETE 大写确认词
echo   - 还需要输入 PAT 作为二次安全锁
echo.
pause
exit /b 0

:mode_default
set "NO_MERGE="
goto :after_param

:mode_no_merge
set "NO_MERGE=1"

echo.
echo ============================================================
echo   [危险操作] -nomerge 模式
echo ============================================================
echo.
echo   这将直接删除当前分支, 不合并到 dev。
echo   该分支上未 commit 的所有改动都将永久丢失。
echo   工作区里未提交的改动会继承到 dev。
echo.
echo   当前分支:
for /f "delims=" %%b in ('git branch --show-current') do echo     %%b
echo.

set "CONFIRM="
set /p "CONFIRM=输入 DELETE 大写确认: "
if not "!CONFIRM!"=="DELETE" (
    echo.
    echo [取消] 输入不匹配, 已退出。
    exit /b 1
)

echo.
echo 请再次输入 GitHub PAT 作为安全锁, 输入不显示:

set "PAT_TMP=%TEMP%\pat_lock_%RANDOM%%RANDOM%.txt"
powershell -NoProfile -Command "$sec = Read-Host -AsSecureString 'PAT'; $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec); $p = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b); [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b); Write-Output $p" > "%PAT_TMP%" 2>nul

set "LOCK_PAT="
for /f "usebackq delims=" %%p in ("%PAT_TMP%") do set "LOCK_PAT=%%p"
del "%PAT_TMP%" 2>nul

if not defined LOCK_PAT (
    echo [取消] 未输入。
    exit /b 1
)
if "!LOCK_PAT:~30!"=="" (
    echo [取消] 输入过短, 疑似误操作, 长度至少应为 30。
    exit /b 1
)
set "LOCK_PAT="
echo [OK] 二次确认通过。
echo.
goto :after_param

:: ---------- 公共流程 ----------
:after_param
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [错误] 当前目录不是 Git 仓库: %CD%
    exit /b 1
)

set "REMOTE_URL="
for /f "delims=" %%r in ('git remote get-url origin 2^>nul') do set "REMOTE_URL=%%r"
if not defined REMOTE_URL (
    echo [错误] 没有找到 origin 远程。
    exit /b 1
)
echo [信息] origin = %REMOTE_URL%

echo %REMOTE_URL% | findstr /b /c:"https://" >nul
if errorlevel 1 (
    echo.
    echo [错误] 当前 origin 不是 HTTPS 协议。
    echo        请先执行: git remote set-url origin https://github.com/Flash-Nova/BPU26.git
    echo.
    exit /b 1
)

set "CURRENT="
for /f "delims=" %%b in ('git branch --show-current') do set "CURRENT=%%b"
if not defined CURRENT (
    echo [错误] 当前处于 detached HEAD 状态。
    exit /b 1
)
if /i "%CURRENT%"=="dev" (
    echo [错误] 当前已经在 dev 分支上, 无需 close。
    exit /b 1
)

echo.
echo ============================================================
echo   当前分支: %CURRENT%
echo ============================================================
echo.

:: 脏检查: 仅默认模式需要
if not defined NO_MERGE (
    set "DIRTY="
    for /f "delims=" %%u in ('git status --porcelain') do set "DIRTY=1"
    if defined DIRTY (
        echo [错误] 当前分支存在未提交的修改, 已拒绝 close。
        echo.
        git status --short
        echo.
        echo 请先 commit 或 stash 之后再执行 close。
        exit /b 1
    )
    echo [OK] 工作区干净。
) else (
    echo [提示] nomerge 模式: 跳过脏检查, 未提交改动会继承到 dev。
)

:: ---------- nomerge 分支: 切到 dev, 未提交改动继承过去 ----------
if defined NO_MERGE (
    echo.
    echo [信息] nomerge 模式: 切到 dev, 未提交改动会继承过去...
    git checkout dev
    if errorlevel 1 (
        echo.
        echo [错误] 切到 dev 失败。
        echo        通常是未提交改动与 dev 上的同名文件冲突。
        echo        请手动处理: git stash push -u 后再重试, 或先 commit。
        exit /b 1
    )
    git branch -D "%CURRENT%"
    if errorlevel 1 (
        echo [错误] 删除分支 %CURRENT% 失败。
        exit /b 1
    )
    echo [OK] 分支 %CURRENT% 已删除, 未合并到 dev。
    echo     工作区未提交的改动现在挂在 dev 上。
    echo.
    echo ============================================================
    echo   close nomerge 完成
    echo   当前分支:
    git branch --show-current
    echo ============================================================
    echo.
    endlocal
    exit /b 0
)

:: ---------- 默认模式: 完整流程 ----------
set "GIT_USER_NAME="
set "GIT_USER_EMAIL="
for /f "delims=" %%u in ('git config --global user.name 2^>nul') do set "GIT_USER_NAME=%%u"
for /f "delims=" %%e in ('git config --global user.email 2^>nul') do set "GIT_USER_EMAIL=%%e"

set "FAKE_GLOBAL=%TEMP%\git_fake_global_%RANDOM%.tmp"
set "FAKE_SYSTEM=%TEMP%\git_fake_system_%RANDOM%.tmp"

(
    echo [user]
    if defined GIT_USER_NAME  echo     name = !GIT_USER_NAME!
    if defined GIT_USER_EMAIL echo     email = !GIT_USER_EMAIL!
) > "%FAKE_GLOBAL%"
echo # empty > "%FAKE_SYSTEM%"

set "GIT_CONFIG_GLOBAL=%FAKE_GLOBAL%"
set "GIT_CONFIG_SYSTEM=%FAKE_SYSTEM%"

@REM set "EMPTY="
@REM git config --local credential.helper "%EMPTY%"
@REM git config --local --add credential.helper "cache --timeout=120"

git config --local --remove-section credential 2>nul
git config --local --add credential.helper "cache --timeout=120"

set "HOST="
set "USERNAME="
for /f "delims=" %%x in ('powershell -NoProfile -Command "$u='%REMOTE_URL%'; if ($u -match '^https://([^/@]+)@([^/]+)/') { Write-Output ('H=' + $matches[2]); Write-Output ('U=' + $matches[1]) } elseif ($u -match '^https://([^/]+)/') { Write-Output ('H=' + $matches[1]); Write-Output 'U=git' } else { Write-Output 'H='; Write-Output 'U=' }"') do (
    set "LINE=%%x"
    if "!LINE:~0,2!"=="H=" set "HOST=!LINE:~2!"
    if "!LINE:~0,2!"=="U=" set "USERNAME=!LINE:~2!"
)

if not defined HOST (
    echo [错误] 无法从 origin 解析出主机名: %REMOTE_URL%
    exit /b 1
)

echo.
echo ------------------------------------------------------------
echo  请输入 GitHub Personal Access Token (PAT)
echo  - 输入不会显示在屏幕上
echo  - 仅缓存在内存中 120 秒, 跑完立即清空
echo  - 全局凭据管理器 GCM 已被本脚本临时屏蔽
echo ------------------------------------------------------------
echo.

set "PAT_TMP=%TEMP%\pat_main_%RANDOM%%RANDOM%.txt"
powershell -NoProfile -Command "$sec = Read-Host -AsSecureString 'PAT'; $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec); $p = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b); [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b); Write-Output $p" > "%PAT_TMP%" 2>nul

set "PAT="
for /f "usebackq delims=" %%p in ("%PAT_TMP%") do set "PAT=%%p"
del "%PAT_TMP%" 2>nul

if not defined PAT (
    echo [错误] 未输入 PAT, 已取消。
    exit /b 1
)

(
    echo protocol=https
    echo host=%HOST%
    echo username=%USERNAME%
    echo password=%PAT%
) | git credential approve

set "PAT="

if errorlevel 1 (
    echo [错误] 凭据写入内存失败。
    exit /b 1
)
echo [OK] PAT 已缓存到内存。

git show-ref --verify --quiet refs/heads/dev
if errorlevel 1 (
    echo [信息] 本地没有 dev 分支, 尝试从 origin 拉取...
    git fetch origin dev
    if errorlevel 1 (
        echo [错误] 无法从 origin 获取 dev 分支。
        exit /b 1
    )
    git checkout -b dev origin/dev
) else (
    git checkout dev
    if errorlevel 1 (
        echo [错误] 切换到 dev 分支失败。
        exit /b 1
    )
)

echo.
echo [信息] 从 origin 同步 dev, 使用 rebase...
git pull --rebase origin dev
if errorlevel 1 (
    echo.
    echo [错误] 无法同步远程 dev。
    echo        请手动处理: git pull --rebase origin dev
    exit /b 1
)
echo [OK] 同步完成。

echo.
echo [信息] 正在合并 %CURRENT% 到 dev ...
git merge --no-ff "%CURRENT%" -m "merge %CURRENT% into dev"
if errorlevel 1 (
    echo.
    echo [错误] 合并失败, 已中止。
    git merge --abort 2>nul
    git checkout "%CURRENT%" 2>nul
    exit /b 1
)
echo [OK] 合并成功。

echo.
echo [信息] 正在推送 dev 到 origin ...
git push origin dev
if errorlevel 1 (
    echo.
    echo [错误] 推送失败。
    exit /b 1
)
echo [OK] 推送成功。

echo.
echo [信息] 正在删除本地临时分支 %CURRENT% ...
git branch -d "%CURRENT%"
if errorlevel 1 (
    echo [警告] 常规删除失败, 尝试强制删除 ...
    git branch -D "%CURRENT%"
    if errorlevel 1 (
        echo [错误] 删除分支 %CURRENT% 失败。
        exit /b 1
    )
)
echo [OK] 分支 %CURRENT% 已删除。

git credential-cache exit 2>nul
echo [OK] PAT 已从内存清除。

del "%FAKE_GLOBAL%" 2>nul
del "%FAKE_SYSTEM%" 2>nul

echo.
echo ============================================================
echo   close 完成
echo   当前分支:
git branch --show-current
echo ============================================================

endlocal
exit /b 0