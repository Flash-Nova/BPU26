@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

:: ============================================================
::  close.bat — 关闭当前临时分支
::  把当前临时分支合并到 dev 并推送到 origin (HTTPS + PAT)
::
::  流程:
::   1. 检查 Git 仓库
::   2. 检查 remote 必须是 HTTPS
::   3. 检查当前分支(不能是 dev)
::   4. 检查是否有未提交修改 -> 有则拒绝
::   5. 隐藏输入 PAT, 仅缓存到内存(120 秒)
::   6. 切到 dev
::   7. 合并临时分支到 dev (失败即停)
::   8. 推送 dev 到 origin (失败即停)
::   9. 删除本地临时分支
::  10. 主动清空内存中的 PAT
:: ============================================================

cd /d "%~dp0"

:: ---------- 1. 检查 Git 仓库 ----------
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [错误] 当前目录不是 Git 仓库: %CD%
    pause
    exit /b 1
)

:: ---------- 2. 检查 remote 是 HTTPS ----------
set "REMOTE_URL="
for /f "delims=" %%r in ('git remote get-url origin 2^>nul') do set "REMOTE_URL=%%r"

if not defined REMOTE_URL (
    echo [错误] 没有找到 origin 远程。
    pause
    exit /b 1
)

echo [信息] origin = %REMOTE_URL%

echo %REMOTE_URL% | findstr /b /c:"https://" >nul
if errorlevel 1 (
    echo.
    echo [错误] 当前 origin 不是 HTTPS 协议，无法使用 PAT 方式提交。
    echo        请先执行下面这条命令切换到 HTTPS:
    echo.
    echo    git remote set-url origin https://github.com/Flash-Nova/BPU26.git
    echo.
    pause
    exit /b 1
)

:: ---------- 3. 获取当前分支 ----------
set "CURRENT="
for /f "delims=" %%b in ('git branch --show-current') do set "CURRENT=%%b"

if not defined CURRENT (
    echo [错误] 当前处于 detached HEAD 状态，无法提交。
    pause
    exit /b 1
)
if /i "%CURRENT%"=="dev" (
    echo [错误] 当前已经在 dev 分支上，无需 close。
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   当前分支: %CURRENT%
echo ============================================================
echo.

:: ---------- 4. 检查是否有未提交修改 ----------
set "DIRTY="
for /f "delims=" %%u in ('git status --porcelain') do set "DIRTY=1"

if defined DIRTY (
    echo [错误] 当前分支存在未提交的修改，已拒绝 close。
    echo.
    git status --short
    echo.
    echo 请先 commit 或 stash 之后再执行 close。
    pause
    exit /b 1
)
echo [OK] 工作区干净。

:: ---------- 5. 内存缓存配置 + 隐藏输入 PAT ----------
::  用空 helper 清掉全局/系统 helper (避免写进 Windows 凭据管理器)
::  只用 cache, 120 秒内存过期, 进程结束即清空
set "EMPTY="
git config --local credential.helper "%EMPTY%"
git config --local --add credential.helper "cache --timeout=120"

:: 解析 host 和 username
set "HOST="
set "USERNAME="
for /f "delims=" %%x in ('powershell -NoProfile -Command "$u='%REMOTE_URL%'; if ($u -match '^https://([^/@]+)@([^/]+)/') { Write-Output ('H=' + $matches[2]); Write-Output ('U=' + $matches[1]) } elseif ($u -match '^https://([^/]+)/') { Write-Output ('H=' + $matches[1]); Write-Output 'U=git' } else { Write-Output 'H='; Write-Output 'U=' }"') do (
    set "LINE=%%x"
    if "!LINE:~0,2!"=="H=" set "HOST=!LINE:~2!"
    if "!LINE:~0,2!"=="U=" set "USERNAME=!LINE:~2!"
)

if not defined HOST (
    echo [错误] 无法从 origin 解析出主机名: %REMOTE_URL%
    pause
    exit /b 1
)

echo.
echo ------------------------------------------------------------
echo  请输入 GitHub Personal Access Token (PAT)
echo  - 输入不会显示在屏幕上
echo  - 仅缓存在内存中 120 秒, 跑完立即清空
echo ------------------------------------------------------------
echo.

for /f "delims=" %%p in ('powershell -NoProfile -Command "$sec = Read-Host -AsSecureString 'PAT'; $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec); $p = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b); [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b); Write-Output $p"') do set "PAT=%%p"

if not defined PAT (
    echo [错误] 未输入 PAT，已取消。
    pause
    exit /b 1
)

:: 把凭据交给 git credential cache 守护进程 (内存)
(
    echo protocol=https
    echo host=%HOST%
    echo username=%USERNAME%
    echo password=%PAT%
) | git credential approve

set "PAT="

if errorlevel 1 (
    echo [错误] 凭据写入内存失败。
    pause
    exit /b 1
)
echo [OK] PAT 已缓存到内存。

:: ---------- 6. 切到 dev ----------
git show-ref --verify --quiet refs/heads/dev
if errorlevel 1 (
    echo [信息] 本地没有 dev 分支，尝试从 origin 拉取...
    git fetch origin dev
    if errorlevel 1 (
        echo [错误] 无法从 origin 获取 dev 分支。
        pause
        exit /b 1
    )
    git checkout -b dev origin/dev
    if errorlevel 1 (
        echo [错误] 创建本地 dev 分支失败。
        pause
        exit /b 1
    )
) else (
    git checkout dev
    if errorlevel 1 (
        echo [错误] 切换到 dev 分支失败。
        pause
        exit /b 1
    )
)

:: 顺手同步一下远端 dev, 避免落后
git pull --ff-only origin dev 2>nul
if errorlevel 1 (
    echo [警告] git pull --ff-only 未成功(可能是首次推送或存在分叉)，继续执行。
)

:: ---------- 7. 合并当前分支到 dev ----------
echo.
echo [信息] 正在合并 %CURRENT% 到 dev ...
git merge --no-ff "%CURRENT%" -m "merge %CURRENT% into dev"
if errorlevel 1 (
    echo.
    echo [错误] 合并失败，已中止合并操作。
    git merge --abort 2>nul
    git checkout "%CURRENT%" 2>nul
    pause
    exit /b 1
)
echo [OK] 合并成功。

:: ---------- 8. 推送 dev 到 origin ----------
echo.
echo [信息] 正在推送 dev 到 origin ...
git push origin dev
if errorlevel 1 (
    echo.
    echo [错误] 推送失败。
    pause
    exit /b 1
)
echo [OK] 推送成功。

:: ---------- 9. 删除本地临时分支 ----------
echo.
echo [信息] 正在删除本地临时分支 %CURRENT% ...
git branch -d "%CURRENT%"
if errorlevel 1 (
    echo [警告] 常规删除失败，尝试强制删除 ...
    git branch -D "%CURRENT%"
    if errorlevel 1 (
        echo [错误] 删除分支 %CURRENT% 失败，请手动处理。
        pause
        exit /b 1
    )
)
echo [OK] 分支 %CURRENT% 已删除。

:: ---------- 10. 主动清空内存中的 PAT ----------
git credential-cache exit 2>nul
echo [OK] PAT 已从内存清除。

:: ---------- 完成 ----------
echo.
echo ============================================================
echo   close 完成！
echo   当前分支:
git branch --show-current
echo ============================================================
echo.

pause
endlocal