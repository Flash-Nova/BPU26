# BPU26

C 语言 & AI 课程笔记仓库。每天一个临时分支，事后合并到 `dev`。

---

## 一、分支规范 Branch Standard

### 1. 命名逻辑 Naming Logic

分支头是日期，形如 `20260929`。

分支尾是类型：
- C 语言课堂上的分支是 `-c`
- 人工智能课堂上的分支是 `-ai`
- 其他时段的分支暂定为 `-other`

例如：`2026 年 9 月 29 日` C 语言课上的分支为 `20260929-c`。

### 2. 分支生命周期 Branch Lifecycle

- **临时分支**：每次上课或写作业时创建，**仅保留在本地**，不推送 GitHub
- **dev 分支**：主开发线，所有临时分支最终合并到这里，并由 `close` 推送到 GitHub
- **main 分支**：GitHub 上的默认分支，暂不使用

---

## 二、脚本说明 Scripts

仓库根目录下有以下脚本。

### newb.bat — 创建今日分支

```
newb.bat                   按日期+课型创建分支
newb.bat -custom <name>    创建自定义名字的分支
newb.bat ?                 显示帮助
```

默认行为：
1. 切到 `dev` 并同步 `origin/dev`
2. 按当前日期和时间决定分支名：
   - 周二/周四 08:00-10:00 → `yyyyMMdd-c`
   - 周三 08:00-10:00 → `yyyyMMdd-ai`
   - 其他时段 → `yyyyMMdd-other`
3. 创建同名目录 `date/<分支名>`
4. 若 `dev` 上有未提交的改动，会随新分支一起带过去

`-custom` 模式：
- 分支名只允许 ASCII 字母、数字、横杠
- 用于临时实验、非课表任务

### execute.bat — 编译 / 运行

```
execute.bat <name>              在整个仓库搜索名为 <name> 的源文件
execute.bat <name> -d <dir>     只在指定目录下搜索
execute.bat ?                   显示帮助
```

行为：
- 支持后缀 `.c` `.cpp` `.cc` `.cxx` `.py`
- 找到 1 个匹配 → 直接编译/运行
- 找到多个匹配 → 列出菜单让你选
- `.c` 使用 gcc，`.cpp` 使用 g++
- `.py` 优先使用仓库根目录下的 `.venv`，否则用系统 python
- C/C++ 编译时加 `-fexec-charset=GBK`，让源文件中的中文在 cmd 里正常显示

### close.bat — 关闭当前分支

```
close.bat              合并到 dev + 推送 + 删除分支
close.bat -nomerge     直接删除分支，不合并（危险）
close.bat ?            显示帮助
```

默认流程：
1. 检查工作区必须干净
2. 隐藏输入 GitHub PAT（暂存于临时文件，跑完即删）
3. 切到 `dev`，`git pull --rebase` 同步
4. `git merge --no-ff` 合并临时分支到 `dev`
5. `git push origin dev`
6. 删除本地临时分支
7. 清理 PAT

`-nomerge` 说明：
- 直接删除当前分支，**未 commit 的改动会丢失**
- 工作区里**未提交的改动**会继承到 `dev`
- 需要输入 `DELETE` 大写确认词 + PAT 二次锁

### new_venv.bat / quit_venv.bat — 虚拟环境

```
new_venv.bat     创建 .venv 并激活
quit_venv.bat    退出 .venv
```

`.venv` 目录已在 `.gitignore` 中，不会被提交。

---

## 三、日常使用流程 Workflow

### 一次完整的课程循环

1. 进入仓库根目录
2. `newb.bat` → 创建今日分支（如 `20261008-c`）
3. 在 `date/<分支名>/` 下写代码、记笔记
4. `execute.bat <文件名>` → 编译/运行验证
5. `git add . && git commit -m "..."` → 提交改动
6. `close.bat` → 合并到 `dev` + 推送 GitHub

### 特殊任务

```
newb.bat -custom test01        → 建一个叫 test01 的实验分支
（...干活...）
close.bat                      → 正常合并到 dev
```

### 只想删分支，不想合并

```
close.bat -nomerge             → 直接删分支
（未提交的改动会继承到 dev）
```

### 只想在某个目录里找文件

```
execute.bat hw -d date\20260929-c
```

---

## 四、注意事项 Notes

### ⚠️ 基础构筑工具必须在 dev 分支上修改

**`newb.bat`、`close.bat`、`execute.bat`、`new_venv.bat`、`quit_venv.bat`、`.gitignore`、`.vscode/` 等属于"基础构筑"，必须在 `dev` 分支上修改并提交。**

原因：
- 这些脚本是给所有分支用的公共工具，不属于任何一天的作业
- 如果在临时分支上修改，`close.bat` 执行 `git checkout dev` 时，**磁盘上的脚本会被 git 换成 dev 的版本**
- Windows cmd 在执行 bat 文件时，如果文件被中途修改，会导致执行混乱甚至中断

**正确做法**：

```
git checkout dev
（修改脚本）
git add .
git commit -m "chore: ..."
git push origin dev
```

**错误做法**：

```
（在临时分支上改脚本，然后 close 时卡死）
```

### 编码约定

- `.bat` 文件保存为 **GBK**（中文 Windows cmd 的默认代码页是 936）
- `.md` `.c` `.cpp` `.py` `.json` 等保存为 **UTF-8**
- VS Code 已通过 `.vscode/settings.json` 为 `.bat` 文件设置默认 GBK

### PAT 使用

- `close.bat` 需要输入 GitHub Personal Access Token (PAT)
- PAT 仅暂存于 `%TEMP%` 下的临时文件，脚本结束时立即删除
- 建议使用 fine-grained token，只授权 `Contents: Read and write` 权限，限定本仓库
- PAT 保存位置：[语雀私密文档](https://www.yuque.com/flashnova/secret/pmyn6v6xnncpwfoe)

---

## 五、目录结构 Directory Layout

```
BPU26/
├── .vscode/               VS Code 工作区配置
├── date/                  各次课的工作目录
│   ├── 20260929-c/        9月29日 C 语言课
│   ├── 20260930-ai/       9月30日 AI 课
│   └── 20261008-c/        10月8日 C 语言课
├── .venv/                 Python 虚拟环境（git 忽略）
├── .gitignore
├── README.md
├── newb.bat
├── close.bat
├── execute.bat
├── new_venv.bat
└── quit_venv.bat
```

---

## 六、待办 TODO

- [ ] 编写 release 工具（一键 clone / 一键铲平，C++ 单 exe）
- [ ] 补全历史项目的 README

---

_最后更新：2026-10-08_