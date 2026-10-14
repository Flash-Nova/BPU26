# close.ps1 - 关闭当前临时分支
# 主逻辑放 PowerShell，防止 cmd 逐行读 bat 被 git checkout 替换导致错位

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot
[Environment]::CurrentDirectory = $repoRoot

# ---------- 函数定义必须在调用之前 ----------
function Cleanup {
    git config --local --remove-section credential 2>$null
    Remove-Item $credFile -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\git_cred_*.tmp" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\pat_*.txt" -Force -ErrorAction SilentlyContinue
    Remove-Item $fakeGlobal -Force -ErrorAction SilentlyContinue
    Remove-Item $fakeSystem -Force -ErrorAction SilentlyContinue
}

function Show-Help {
    Write-Host "============================================================"
    Write-Host "  close - 关闭当前临时分支"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "用法:"
    Write-Host "  close.bat              默认: 合并到 dev + 推送 + 删除分支"
    Write-Host "  close.bat -nomerge     危险: 直接删除分支, 未提交改动继承到 dev"
    Write-Host "  close.bat ?            显示本帮助"
    Write-Host ""
}

# ---------- 参数解析 ----------
$arg1 = if ($args.Count -ge 1) { $args[0] } else { '' }

if ($arg1 -eq '?' -or $arg1 -eq '-h' -or $arg1 -eq '--help') {
    Show-Help
    exit 0
}

$noMerge = $false
if ($arg1 -eq '-nomerge') { $noMerge = $true }
elseif ($arg1 -ne '') {
    Write-Host "[错误] 未知参数: $arg1"
    Show-Help
    exit 1
}

# ---------- 兜底清理 ----------
Remove-Item "$env:TEMP\git_cred_*.tmp" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\pat_*.txt" -Force -ErrorAction SilentlyContinue

# ---------- -nomerge 模式 ----------
if ($noMerge) {
    if (-not (Test-Path ".git")) {
        Write-Host "[错误] 当前目录不是 Git 仓库: $(Get-Location)"
        exit 1
    }

    $current = (git branch --show-current).Trim()
    if (-not $current) {
        Write-Host "[错误] 当前处于 detached HEAD 状态。"
        exit 1
    }
    if ($current -eq 'dev') {
        Write-Host "[错误] 当前已经在 dev 分支上, 无需 close。"
        exit 1
    }

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "  [危险操作] -nomerge 模式"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  这将直接删除当前分支, 不合并到 dev。"
    Write-Host "  该分支上未 commit 的所有改动都将永久丢失。"
    Write-Host "  工作区里未提交的改动会继承到 dev。"
    Write-Host ""
    Write-Host "  当前分支: $current"
    Write-Host ""

    $confirm = Read-Host "输入 DELETE 大写确认"
    if ($confirm -ne 'DELETE') {
        Write-Host ""
        Write-Host "[取消] 输入不匹配, 已退出。"
        exit 1
    }

    Write-Host ""
    Write-Host "请再次输入 GitHub PAT 作为安全锁, 输入不显示:"
    $secure = Read-Host -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $lockPat = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    if (-not $lockPat) {
        Write-Host "[取消] 未输入。"
        exit 1
    }
    if ($lockPat.Length -lt 30) {
        Write-Host "[取消] 输入过短, 疑似误操作, 长度至少应为 30。"
        exit 1
    }
    $lockPat = $null
    Write-Host "[OK] 二次确认通过。"
    Write-Host ""

    Write-Host "[信息] nomerge 模式: 切到 dev, 未提交改动会继承过去..."
    git checkout dev
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] 切到 dev 失败。"
        exit 1
    }
    git branch -D $current
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] 删除分支 $current 失败。"
        exit 1
    }
    Write-Host "[OK] 分支 $current 已删除, 未合并到 dev。"
    Write-Host "     工作区未提交的改动现在挂在 dev 上。"
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "  close nomerge 完成"
    Write-Host "  当前分支: $(git branch --show-current)"
    Write-Host "============================================================"
    Remove-Item "$env:TEMP\git_cred_*.tmp" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\pat_*.txt" -Force -ErrorAction SilentlyContinue
    exit 0
}

# ---------- 默认模式 ----------
if (-not (Test-Path ".git")) {
    Write-Host "[错误] 当前目录不是 Git 仓库: $(Get-Location)"
    exit 1
}

$remoteUrl = (git remote get-url origin 2>$null)
if (-not $remoteUrl) {
    Write-Host "[错误] 没有找到 origin 远程。"
    exit 1
}
Write-Host "[信息] origin = $remoteUrl"

if (-not $remoteUrl.StartsWith('https://')) {
    Write-Host ""
    Write-Host "[错误] 当前 origin 不是 HTTPS 协议。"
    Write-Host "        请先执行: git remote set-url origin https://github.com/Flash-Nova/BPU26.git"
    Write-Host ""
    exit 1
}

$current = (git branch --show-current).Trim()
if (-not $current) {
    Write-Host "[错误] 当前处于 detached HEAD 状态。"
    exit 1
}
if ($current -eq 'dev') {
    Write-Host "[错误] 当前已经在 dev 分支上, 无需 close。"
    exit 1
}

Write-Host ""
Write-Host "============================================================"
Write-Host "  当前分支: $current"
Write-Host "============================================================"
Write-Host ""

$dirty = git status --porcelain
if ($dirty) {
    Write-Host "[错误] 当前分支存在未提交的修改, 已拒绝 close。"
    Write-Host ""
    $dirty | ForEach-Object { Write-Host $_ }
    Write-Host ""
    Write-Host "请先 commit 或 stash 之后再执行 close。"
    exit 1
}
Write-Host "[OK] 工作区干净。"

$gitUserName = (git config --global user.name 2>$null)
$gitUserEmail = (git config --global user.email 2>$null)

$fakeGlobal = "$env:TEMP\git_fake_global_$([System.IO.Path]::GetRandomFileName()).tmp"
$fakeSystem = "$env:TEMP\git_fake_system_$([System.IO.Path]::GetRandomFileName()).tmp"

$fakeContent = "[user]`n"
if ($gitUserName)  { $fakeContent += "    name = $gitUserName`n" }
if ($gitUserEmail) { $fakeContent += "    email = $gitUserEmail`n" }
Set-Content -Path $fakeGlobal -Value $fakeContent -Encoding ASCII
Set-Content -Path $fakeSystem -Value "# empty" -Encoding ASCII

$env:GIT_CONFIG_GLOBAL = $fakeGlobal
$env:GIT_CONFIG_SYSTEM = $fakeSystem

git config --local --remove-section credential 2>$null
$credFile = "$env:TEMP\git_cred_$([System.IO.Path]::GetRandomFileName()).tmp"
git config --local --add credential.helper "store --file=$credFile"

$host_ = $null
$username = $null
if ($remoteUrl -match '^https://([^/@]+)@([^/]+)/') {
    $username = $Matches[1]
    $host_ = $Matches[2]
} elseif ($remoteUrl -match '^https://([^/]+)/') {
    $host_ = $Matches[1]
    $username = 'git'
} else {
    Write-Host "[错误] 无法从 origin 解析出主机名: $remoteUrl"
    exit 1
}

Write-Host ""
Write-Host "------------------------------------------------------------"
Write-Host "  请输入 GitHub Personal Access Token (PAT)"
Write-Host "  - 输入不会显示在屏幕上"
Write-Host "  - 暂存于临时文件, 脚本结束时立即删除"
Write-Host "  - 全局凭据管理器 GCM 已被本脚本临时屏蔽"
Write-Host "------------------------------------------------------------"
Write-Host ""

$secure = Read-Host -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
$pat = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

if (-not $pat) {
    Write-Host "[错误] 未输入 PAT, 已取消。"
    exit 1
}

Set-Content -Path $credFile -Value "https://${username}:${pat}@${host_}" -Encoding ASCII
$pat = $null
Write-Host "[OK] PAT 已暂存。"

git show-ref --verify --quiet refs/heads/dev
if ($LASTEXITCODE -ne 0) {
    Write-Host "[信息] 本地没有 dev 分支, 尝试从 origin 拉取..."
    git fetch origin dev
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] 无法从 origin 获取 dev 分支。"
        Cleanup
        exit 1
    }
    git checkout -b dev origin/dev
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] 创建本地 dev 分支失败。"
        Cleanup
        exit 1
    }
} else {
    git checkout dev
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] 切换到 dev 分支失败。"
        Cleanup
        exit 1
    }
}

Write-Host ""
Write-Host "[信息] 从 origin 同步 dev, 使用 rebase..."
git pull --rebase origin dev
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[错误] 无法同步远程 dev。"
    Write-Host "        请手动处理: git pull --rebase origin dev"
    Cleanup
    exit 1
}
Write-Host "[OK] 同步完成。"

Write-Host ""
Write-Host "[信息] 正在合并 $current 到 dev ..."
git merge --no-ff $current -m "merge $current into dev"
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[错误] 合并失败, 已中止。"
    git merge --abort 2>$null
    git checkout $current 2>$null
    Cleanup
    exit 1
}
Write-Host "[OK] 合并成功。"

Write-Host ""
Write-Host "[信息] 正在推送 dev 到 origin ..."
git push origin dev
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[错误] 推送失败。"
    Cleanup
    exit 1
}
Write-Host "[OK] 推送成功。"

Write-Host ""
Write-Host "[信息] 正在删除本地临时分支 $current ..."
git branch -d $current
if ($LASTEXITCODE -ne 0) {
    Write-Host "[警告] 常规删除失败, 尝试强制删除 ..."
    git branch -D $current
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] 删除分支 $current 失败。"
        Cleanup
        exit 1
    }
}
Write-Host "[OK] 分支 $current 已删除。"

Cleanup

Write-Host ""
Write-Host "============================================================"
Write-Host "  close 完成"
Write-Host "  当前分支: $(git branch --show-current)"
Write-Host "============================================================"
Write-Host ""

exit 0