# -*- coding: utf-8 -*-
import getpass
import glob
import os
import subprocess
import sys
import tempfile
from pathlib import Path

if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

REPO_ROOT = Path(__file__).resolve().parent
os.chdir(REPO_ROOT)

FAKE_GLOBAL = None
FAKE_SYSTEM = None


# ============================================================
#  ASKPASS 分支：git 回调时走这里
#  被 close.bat 调用为: close.py --askpass "<prompt>"
# ============================================================
def handle_askpass():
    # sys.argv[1] 是 --askpass，真正的 prompt 在 argv[2]
    prompt = sys.argv[2] if len(sys.argv) >= 3 else ''
    p = prompt.lower()

    if 'username' in p or '用户名' in p:
        sys.stdout.write(os.environ.get('GIT_USERNAME', 'git') + '\n')
    elif 'password' in p or '密码' in p:
        sys.stdout.write(os.environ.get('GIT_PAT', '') + '\n')
    else:
        # 兜底：有 PAT 就给 PAT
        if os.environ.get('GIT_PAT'):
            sys.stdout.write(os.environ['GIT_PAT'] + '\n')
        else:
            sys.exit(1)
    return 0


# ============================================================
#  正常逻辑
# ============================================================
def run_git(*args):
    return subprocess.call(['git'] + list(args), cwd=str(REPO_ROOT))


def current_branch():
    try:
        return subprocess.check_output(
            ['git', 'branch', '--show-current'],
            text=True, cwd=str(REPO_ROOT)).strip()
    except subprocess.CalledProcessError:
        return ''


def line():
    print("============================================================")


def cleanup():
    subprocess.call(
        ['git', 'config', '--local', '--remove-section', 'credential'],
        cwd=str(REPO_ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL)
    for k in ('GIT_PAT', 'GIT_USERNAME', 'GIT_ASKPASS', 'GIT_ASKPASS_MARKER',
              'GIT_TERMINAL_PROMPT', 'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_SYSTEM'):
        os.environ.pop(k, None)
    for f in (FAKE_GLOBAL, FAKE_SYSTEM):
        if f and os.path.exists(f):
            try:
                os.remove(f)
            except OSError:
                pass


def show_help():
    line()
    print("  close - 关闭当前临时分支")
    line()
    print()
    print("用法:")
    print("  close.bat              默认: 合并到 dev + 推送 + 删除分支")
    print("  close.bat -nomerge     危险: 直接删除分支, 未提交改动继承到 dev")
    print("  close.bat ?            显示本帮助")
    print("  close.bat -h           显示本帮助")
    print("  close.bat --help       显示本帮助")
    print()


def setup_askpass(pat):
    """PAT 塞进环境变量, git 回调 close.bat 读回"""
    os.environ['GIT_USERNAME'] = 'git'
    os.environ['GIT_PAT'] = pat
    os.environ['GIT_ASKPASS'] = str(REPO_ROOT / 'close.bat')
    os.environ['GIT_ASKPASS_MARKER'] = '1'
    os.environ['GIT_TERMINAL_PROMPT'] = '0'


def fake_git_config():
    global FAKE_GLOBAL, FAKE_SYSTEM

    user_name = ''
    user_email = ''
    try:
        user_name = subprocess.check_output(
            ['git', 'config', '--global', 'user.name'],
            stderr=subprocess.DEVNULL, text=True).strip()
    except Exception:
        pass
    try:
        user_email = subprocess.check_output(
            ['git', 'config', '--global', 'user.email'],
            stderr=subprocess.DEVNULL, text=True).strip()
    except Exception:
        pass

    fd, fake_global = tempfile.mkstemp(prefix='git_fake_global_', suffix='.tmp')
    os.close(fd)
    fd, fake_system = tempfile.mkstemp(prefix='git_fake_system_', suffix='.tmp')
    os.close(fd)
    FAKE_GLOBAL = fake_global
    FAKE_SYSTEM = fake_system

    with open(fake_global, 'w', encoding='ascii') as f:
        f.write('[user]\n')
        if user_name:
            f.write(f'    name = {user_name}\n')
        if user_email:
            f.write(f'    email = {user_email}\n')
    with open(fake_system, 'w', encoding='ascii') as f:
        f.write('# empty\n')

    os.environ['GIT_CONFIG_GLOBAL'] = fake_global
    os.environ['GIT_CONFIG_SYSTEM'] = fake_system


def sweep_temp():
    tmp = os.environ.get('TEMP', '')
    for pat in (os.path.join(tmp, 'git_cred_*.tmp'),
                os.path.join(tmp, 'pat_*.txt')):
        for f in glob.glob(pat):
            try:
                os.remove(f)
            except OSError:
                pass


def mode_nomerge():
    if not os.path.exists('.git'):
        print(f"[错误] 当前目录不是 Git 仓库: {os.getcwd()}")
        return 1

    cur = current_branch()
    if not cur:
        print("[错误] 当前处于 detached HEAD 状态。")
        return 1
    if cur == 'dev':
        print("[错误] 当前已经在 dev 分支上, 无需 close。")
        return 1

    print()
    line()
    print("  [危险操作] -nomerge 模式")
    line()
    print()
    print("  这将直接删除当前分支, 不合并到 dev。")
    print("  该分支上未 commit 的所有改动都将永久丢失。")
    print("  工作区里未提交的改动会继承到 dev。")
    print()
    print(f"  当前分支: {cur}")
    print()

    confirm = input("输入 DELETE 大写确认: ").strip()
    if confirm != 'DELETE':
        print()
        print("[取消] 输入不匹配, 已退出。")
        return 1

    print()
    print("请再次输入 GitHub PAT 作为安全锁, 输入不显示:")
    lock_pat = getpass.getpass('')

    if not lock_pat:
        print("[取消] 未输入。")
        return 1
    if len(lock_pat) < 30:
        print("[取消] 输入过短, 疑似误操作, 长度至少应为 30。")
        return 1
    lock_pat = None
    print("[OK] 二次确认通过。")
    print()

    print("[信息] nomerge 模式: 切到 dev, 未提交改动会继承过去...")
    if run_git('checkout', 'dev') != 0:
        print("[错误] 切到 dev 失败。")
        return 1
    if run_git('branch', '-D', cur) != 0:
        print(f"[错误] 删除分支 {cur} 失败。")
        return 1
    print(f"[OK] 分支 {cur} 已删除, 未合并到 dev。")
    print("     工作区未提交的改动现在挂在 dev 上。")
    print()
    line()
    print("  close nomerge 完成")
    print(f"  当前分支: {current_branch()}")
    line()
    return 0


def mode_default():
    if not os.path.exists('.git'):
        print(f"[错误] 当前目录不是 Git 仓库: {os.getcwd()}")
        return 1

    try:
        remote_url = subprocess.check_output(
            ['git', 'remote', 'get-url', 'origin'],
            stderr=subprocess.DEVNULL, text=True, cwd=str(REPO_ROOT)).strip()
    except subprocess.CalledProcessError:
        remote_url = ''

    if not remote_url:
        print("[错误] 没有找到 origin 远程。")
        return 1
    print(f"[信息] origin = {remote_url}")

    if not remote_url.startswith('https://'):
        print()
        print("[错误] 当前 origin 不是 HTTPS 协议。")
        print("        请先执行: git remote set-url origin https://github.com/Flash-Nova/BPU26.git")
        print()
        return 1

    cur = current_branch()
    if not cur:
        print("[错误] 当前处于 detached HEAD 状态。")
        return 1
    if cur == 'dev':
        print("[错误] 当前已经在 dev 分支上, 无需 close。")
        return 1

    print()
    line()
    print(f"  当前分支: {cur}")
    line()
    print()

    dirty = subprocess.check_output(
        ['git', 'status', '--porcelain'],
        text=True, cwd=str(REPO_ROOT)).strip()
    if dirty:
        print("[错误] 当前分支存在未提交的修改, 已拒绝 close。")
        print()
        for l in dirty.splitlines():
            print(' ' + l)
        print()
        print("请先 commit 或 stash 之后再执行 close。")
        return 1
    print("[OK] 工作区干净。")

    fake_git_config()
    subprocess.call(
        ['git', 'config', '--local', '--remove-section', 'credential'],
        cwd=str(REPO_ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL)

    print()
    print("------------------------------------------------------------")
    print("  请输入 GitHub Personal Access Token (PAT)")
    print("  - 输入不会显示在屏幕上")
    print("  - 只存内存环境变量, 不落地任何文件")
    print("  - 全局凭据管理器 GCM 已被本脚本临时屏蔽")
    print("------------------------------------------------------------")
    print()

    pat = getpass.getpass('PAT: ')
    if not pat:
        print("[错误] 未输入 PAT, 已取消。")
        cleanup()
        return 1

    setup_askpass(pat)
    pat = None
    print("[OK] PAT 已注入内存环境变量。")

    if run_git('show-ref', '--verify', '--quiet', 'refs/heads/dev') != 0:
        print("[信息] 本地没有 dev 分支, 尝试从 origin 拉取...")
        if run_git('fetch', 'origin', 'dev') != 0:
            print("[错误] 无法从 origin 获取 dev 分支。")
            cleanup()
            return 1
        if run_git('checkout', '-b', 'dev', 'origin/dev') != 0:
            print("[错误] 创建本地 dev 分支失败。")
            cleanup()
            return 1
    else:
        if run_git('checkout', 'dev') != 0:
            print("[错误] 切换到 dev 分支失败。")
            cleanup()
            return 1

    print()
    print("[信息] 从 origin 同步 dev, 使用 rebase...")
    if run_git('pull', '--rebase', 'origin', 'dev') != 0:
        print()
        print("[错误] 无法同步远程 dev。")
        print("        请手动处理: git pull --rebase origin dev")
        cleanup()
        return 1
    print("[OK] 同步完成。")

    print()
    print(f"[信息] 正在合并 {cur} 到 dev ...")
    if run_git('merge', '--no-ff', cur, '-m', f'merge {cur} into dev') != 0:
        print()
        print("[错误] 合并失败, 已中止。")
        run_git('merge', '--abort')
        run_git('checkout', cur)
        cleanup()
        return 1
    print("[OK] 合并成功。")

    print()
    print("[信息] 正在推送 dev 到 origin ...")
    if run_git('push', 'origin', 'dev') != 0:
        print()
        print("[错误] 推送失败。")
        cleanup()
        return 1
    print("[OK] 推送成功。")

    print()
    print(f"[信息] 正在删除本地临时分支 {cur} ...")
    if run_git('branch', '-d', cur) != 0:
        print("[警告] 常规删除失败, 尝试强制删除 ...")
        if run_git('branch', '-D', cur) != 0:
            print(f"[错误] 删除分支 {cur} 失败。")
            cleanup()
            return 1
    print(f"[OK] 分支 {cur} 已删除。")

    cleanup()

    print()
    line()
    print("  close 完成")
    print(f"  当前分支: {current_branch()}")
    line()
    print()
    return 0


# ============================================================
#  入口
# ============================================================
def main():
    # askpass 分支（被 git 回调）
    if len(sys.argv) >= 2 and sys.argv[1] == '--askpass':
        return handle_askpass()

    arg1 = sys.argv[1] if len(sys.argv) >= 2 else ''

    if arg1 in ('?', '-h', '--help'):
        show_help()
        return 0

    if arg1 not in ('', '-nomerge'):
        print(f"[错误] 未知参数: {arg1}")
        show_help()
        return 1

    sweep_temp()

    if arg1 == '-nomerge':
        return mode_nomerge()
    else:
        return mode_default()


if __name__ == '__main__':
    sys.exit(main())