# -*- coding: utf-8 -*-
import ctypes
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

def set_console_codepage(cp: int):
    """Windows API 设置当前控制台输入/输出代码页，等价 chcp 命令"""
    if sys.platform != "win32":
        return
    kernel32 = ctypes.windll.kernel32
    kernel32.SetConsoleCP.argtypes = (ctypes.wintypes.UINT,)
    kernel32.SetConsoleOutputCP.argtypes = (ctypes.wintypes.UINT,)
    kernel32.SetConsoleCP.restype = ctypes.wintypes.BOOL
    kernel32.SetConsoleOutputCP.restype = ctypes.wintypes.BOOL
    kernel32.SetConsoleCP(cp)
    kernel32.SetConsoleOutputCP(cp)


REPO_ROOT = Path(__file__).resolve().parent
os.chdir(REPO_ROOT)

FAKE_GLOBAL = None
FAKE_SYSTEM = None

# 本机免 PAT 输入: 标记文件 + Windows 凭据管理器
MARKER_FILE = REPO_ROOT / '.close_local_pat'
CRED_TARGET = 'BPU26_CLOSE_PAT'


# ============================================================
#  星号回显密码输入 (支持 Ctrl+V / 右键粘贴)
# ============================================================
def _read_clipboard():
    """读 Windows 剪贴板文本, 失败返回 None"""
    try:
        import ctypes
        from ctypes import wintypes
        user32 = ctypes.windll.user32
        kernel32 = ctypes.windll.kernel32
        user32.OpenClipboard.argtypes = [wintypes.HWND]
        user32.OpenClipboard.restype = wintypes.BOOL
        user32.GetClipboardData.argtypes = [wintypes.UINT]
        user32.GetClipboardData.restype = wintypes.HANDLE
        kernel32.GlobalLock.argtypes = [wintypes.HANDLE]
        kernel32.GlobalLock.restype = wintypes.LPVOID
        kernel32.GlobalUnlock.argtypes = [wintypes.HANDLE]
        if not user32.OpenClipboard(None):
            return None
        try:
            h = user32.GetClipboardData(13)  # CF_UNICODETEXT
            if not h:
                return None
            p = kernel32.GlobalLock(h)
            if not p:
                return None
            try:
                return ctypes.wstring_at(p)
            finally:
                kernel32.GlobalUnlock(h)
        finally:
            user32.CloseClipboard()
    except Exception:
        return None


def masked_input(prompt):
    """回显星号的密码输入。支持退格、Ctrl+V 粘贴、控制台右键粘贴。
    非 Windows 或无 msvcrt 时退回 getpass。"""
    if sys.platform != 'win32':
        return getpass.getpass(prompt)
    try:
        import msvcrt
    except ImportError:
        return getpass.getpass(prompt)

    sys.stdout.write(prompt)
    sys.stdout.flush()
    buf = []

    def echo_backspace():
        if buf:
            buf.pop()
            sys.stdout.write('\b \b')
            sys.stdout.flush()

    def echo_char(c):
        buf.append(c)
        sys.stdout.write('*')
        sys.stdout.flush()

    while True:
        ch = msvcrt.getwch()
        if ch in ('\r', '\n'):
            sys.stdout.write('\n')
            sys.stdout.flush()
            break
        if ch == '\x03':  # Ctrl+C
            sys.stdout.write('\n')
            raise KeyboardInterrupt
        if ch in ('\x08', '\x7f'):  # 退格 / Delete
            echo_backspace()
            continue
        if ch == '\x16':  # Ctrl+V 粘贴
            text = _read_clipboard()
            if text:
                for c in text:
                    if c in ('\r', '\n'):  # 只取第一行
                        break
                    if c in ('\x08', '\x7f'):
                        echo_backspace()
                    else:
                        echo_char(c)
            continue
        if ch in ('\x00', '\xe0'):  # 功能键前缀, 吃掉第二个字符
            msvcrt.getwch()
            continue
        echo_char(ch)
    return ''.join(buf)


# ============================================================
#  Windows 凭据管理器 (本地安全存储)
# ============================================================
_CRED_TYPE_GENERIC = 1
_CRED_PERSIST_LOCAL_MACHINE = 2


def _cred_api():
    import ctypes
    from ctypes import wintypes

    class FILETIME(ctypes.Structure):
        _fields_ = [("dwLowDateTime", wintypes.DWORD),
                    ("dwHighDateTime", wintypes.DWORD)]

    class CREDENTIALW(ctypes.Structure):
        _fields_ = [
            ("Flags", wintypes.DWORD),
            ("Type", wintypes.DWORD),
            ("TargetName", wintypes.LPWSTR),
            ("Comment", wintypes.LPWSTR),
            ("LastWritten", FILETIME),
            ("CredentialBlobSize", wintypes.DWORD),
            ("CredentialBlob", ctypes.POINTER(ctypes.c_byte)),
            ("Persist", wintypes.DWORD),
            ("AttributeCount", wintypes.DWORD),
            ("Attributes", ctypes.c_void_p),
            ("TargetAlias", wintypes.LPWSTR),
            ("UserName", wintypes.LPWSTR),
        ]

    advapi32 = ctypes.windll.advapi32
    advapi32.CredReadW.restype = wintypes.BOOL
    advapi32.CredReadW.argtypes = [
        wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
        ctypes.POINTER(ctypes.POINTER(CREDENTIALW))]
    advapi32.CredWriteW.restype = wintypes.BOOL
    advapi32.CredWriteW.argtypes = [ctypes.POINTER(CREDENTIALW), wintypes.DWORD]
    advapi32.CredFree.argtypes = [ctypes.c_void_p]
    return advapi32, CREDENTIALW


def cred_read(target=CRED_TARGET):
    """从凭据管理器读 PAT, 不存在/失败返回 None"""
    if sys.platform != 'win32':
        return None
    try:
        advapi32, CREDENTIALW = _cred_api()
        ptr = ctypes.POINTER(CREDENTIALW)()
        if not advapi32.CredReadW(target, _CRED_TYPE_GENERIC, 0, ctypes.byref(ptr)):
            return None
        try:
            cred = ptr.contents
            if cred.CredentialBlobSize == 0 or not cred.CredentialBlob:
                return None
            blob = ctypes.string_at(cred.CredentialBlob, cred.CredentialBlobSize)
            return blob.decode('utf-8', errors='replace')
        finally:
            advapi32.CredFree(ctypes.cast(ptr, ctypes.c_void_p))
    except Exception:
        return None


def cred_write(secret, target=CRED_TARGET, username='git'):
    """把 PAT 写入凭据管理器"""
    if sys.platform != 'win32':
        return False
    try:
        import ctypes
        advapi32, CREDENTIALW = _cred_api()
        blob = secret.encode('utf-8')
        buf = ctypes.create_string_buffer(blob, len(blob))
        cred = CREDENTIALW()
        cred.Flags = 0
        cred.Type = _CRED_TYPE_GENERIC
        cred.TargetName = target
        cred.Comment = 'BPU26 close.bat PAT'
        cred.CredentialBlobSize = len(blob)
        cred.CredentialBlob = ctypes.cast(buf, ctypes.POINTER(ctypes.c_byte))
        cred.Persist = _CRED_PERSIST_LOCAL_MACHINE
        cred.AttributeCount = 0
        cred.Attributes = None
        cred.TargetAlias = None
        cred.UserName = username
        return bool(advapi32.CredWriteW(ctypes.byref(cred), 0))
    except Exception:
        return False


def is_local_machine():
    """标记文件存在且内容 == 本机用户名"""
    try:
        first_line = MARKER_FILE.read_text(encoding='utf-8').splitlines()[0].strip()
    except Exception:
        return False
    local_user = os.environ.get('USERNAME', '')
    return bool(local_user) and first_line.lower() == local_user.lower()


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
    print("  close - 关闭当前临时分支 / 推送 dev")
    line()
    print()
    print("用法:")
    print("  close.bat              默认: 合并到 dev + 推送 + 删除分支")
    print("  close.bat -nomerge     危险: 直接删除分支, 未提交改动继承到 dev")
    print("  close.bat -pushdev     直接推送当前 dev 分支 (不合并)")
    print("  close.bat ?            显示本帮助")
    print()
    print("PAT 输入:")
    print("  - 星号回显, 支持 Ctrl+V / 右键粘贴")
    print("  - 只存内存环境变量, 不落地任何文件")
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


def prompt_pat():
    """引导用户输入 PAT。本机标记命中且有存储时直接返回, 不再询问。"""
    if is_local_machine():
        pat = cred_read()
        if pat:
            print(f"[OK] 检测到本机标记 ({MARKER_FILE.name}), "
                  "已从 Windows 凭据管理器读取 PAT, 免输入。")
            return pat
        print(f"[信息] 检测到本机标记, 但凭据管理器中尚未存储 PAT。")

    print()
    print("------------------------------------------------------------")
    print("  请输入 GitHub Personal Access Token (PAT)")
    print("  - 输入会回显为星号 (*), 按回车确认")
    print("  - 支持 Ctrl+V 或终端右键粘贴")
    print("  - 只存内存环境变量, 不落地任何文件")
    print("  - 全局凭据管理器 GCM 已被本脚本临时屏蔽")
    print("------------------------------------------------------------")
    print()

    pat = masked_input('PAT: ')
    if not pat:
        print("[错误] 未输入 PAT, 已取消。")
        return None

    # 本机标记命中但还没存 -> 提示存入凭据管理器, 下次免输入
    if is_local_machine() and not cred_read():
        try:
            ans = input("是否把 PAT 存入 Windows 凭据管理器, 以后本机免输入? [y/N]: ")
        except (EOFError, KeyboardInterrupt):
            ans = ''
        if ans.strip().lower() == 'y':
            if cred_write(pat):
                print("[OK] 已存入 Windows 凭据管理器。")
            else:
                print("[警告] 存储失败, 下次仍需手动输入。")
        else:
            print("[信息] 未保存, 下次仍需手动输入。")
    return pat


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

def mode_pushdev():
    if not os.path.exists('.git'):
        print(f"[错误] 当前目录不是 Git 仓库: {os.getcwd()}")
        return 1

    cur = current_branch()
    if cur != 'dev':
        print(f"[错误] 当前分支是 {cur}, 请先切换到 dev 分支再推送。")
        return 1

    print("[信息] 准备推送 dev 分支...")
    
    fake_git_config()
    subprocess.call(
        ['git', 'config', '--local', '--remove-section', 'credential'],
        cwd=str(REPO_ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL)

    try:
        pat = prompt_pat()
    except KeyboardInterrupt:
        print("\n[取消] 用户中断。")
        cleanup()
        return 1
        
    if not pat:
        cleanup()
        return 1

    setup_askpass(pat)
    pat = None
    print("[OK] PAT 已注入内存环境变量。")

    print("\n[信息] 正在推送 dev 到 origin ...")
    if run_git('push', 'origin', 'dev') != 0:
        print("\n[错误] 推送失败。")
        cleanup()
        return 1
    print("[OK] 推送成功。")

    cleanup()
    print("\n============================================================")
    print("  pushdev 完成")
    print("============================================================")
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

    try:
        pat = prompt_pat()
    except KeyboardInterrupt:
        print()
        print("[取消] 用户中断。")
        cleanup()
        return 1
    if not pat:
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
    ret = 1
    try:
        # askpass 分支（被 git 回调）
        if len(sys.argv) >= 2 and sys.argv[1] == '--askpass':
            return handle_askpass()

        arg1 = sys.argv[1] if len(sys.argv) >= 2 else ''

        if arg1 in ('?', '-h', '--help'):
            show_help()
            return 0

        if arg1 not in ('', '-nomerge', '-pushdev'):
            print(f"[错误] 未知参数: {arg1}")
            show_help()
            return 1

        sweep_temp()

        if arg1 == '-nomerge':
            return mode_nomerge()
        elif arg1 == '-pushdev':
            return mode_pushdev()
        else:
            return mode_default()
        
    finally:
        # askpass 回调进程不要执行设置代码页！会破坏git认证
        if sys.platform == "win32" and not (len(sys.argv)>=2 and sys.argv[1] == '--askpass'):
            set_console_codepage(936)
    return ret

if __name__ == '__main__':
    sys.exit(main())