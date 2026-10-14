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
- 自定义任务分支用 `-custom`（见 newb.bat）

例如：`2026 年 9 月 29 日` C 语言课上的分支为 `20260929-c`。

### 2. 分支生命周期 Branch Lifecycle

- **临时分支**：每次上课或写作业时创建，**仅保留在本地**，不推送 GitHub
- **dev 分支**：主开发线，所有临时分支最终合并到这里，并由 `close` 推送到 GitHub
- **main 分支**：稳定发布线，仅当项目达到"正式版"标准时从 dev 合并

---

## 二、脚本说明 Scripts

### newb.bat — 创建今日分支

```
newb.bat                   按日期+课型创建分支
newb.bat -custom <name>    创建自定义名字的分支
newb.bat ?                 显示帮助
```

默认行为：
1. 切到 `dev` 并同步 `origin/dev`
2. 按当前日期和时间决定分支名
   - 周二/周四 08:00-10:00 → `yyyyMMdd-c`
   - 周三 08:00-10:00 → `yyyyMMdd-ai`
   - 其他时段 → `yyyyMMdd-other`
3. 创建同名目录 `date/<分支名>`
4. 若 `dev` 上有未提交改动，会随新分支一起带过去

### execute.bat — 编译 / 运行

```
execute.bat <name>              全仓库搜索 <name> 的源文件
execute.bat <name> -d <dir>     只在指定目录下搜索
execute.bat <name> -f           强制重新编译（跳过时间戳检查）
execute.bat ?                   显示帮助
```

行为：
- 支持后缀 `.c` `.cpp` `.cc` `.cxx` `.py`
- 找到 1 个 → 直接处理；找到多个 → 列出菜单选择
- **时间戳缓存**：exe 比源文件新时跳过编译，直接运行
- `.c` 用 gcc，`.cpp` 用 g++
- `.py` 优先使用根目录 `.venv`，否则用系统 python
- 编译 C/C++ 时加 `-fexec-charset=GBK`，让源文件中的中文在 cmd 正常显示

### close.bat — 关闭当前分支

```
close.bat              合并到 dev + 推送 + 删除分支
close.bat -nomerge     直接删除分支，不合并（危险）
close.bat ?            显示帮助
```

默认流程：
1. 检查工作区必须干净
2. 隐藏输入 GitHub PAT（临时文件，跑完即删）
3. 切到 `dev`，`git pull --rebase` 同步
4. `git merge --no-ff` 合并临时分支到 `dev`
5. `git push origin dev`
6. 删除本地临时分支
7. 清理 PAT

`-nomerge` 说明：
- 直接删除当前分支，**未 commit 的改动会丢失**
- 工作区里**未提交的改动**会继承到 `dev`
- 需要输入 `DELETE` 大写确认词 + PAT 二次锁

### venv.bat — 管理虚拟环境

```
call venv.bat start      创建（若不存在）并激活 .venv
call venv.bat quit       退出当前 .venv
venv.bat ?               显示帮助
```

`.venv/` 已在 `.gitignore` 中。

若使用 cmd 控制台，**必须用 `call` 调用**，否则激活只在子进程里生效，本终端看不到 `(.venv)` 前缀。

vscode terminal 似乎不受影响

---

## 三、日常使用流程 Workflow

### 一次完整的课程循环

1. `newb.bat` → 创建今日分支（如 `20261008-c`）
2. 在 `date/<分支名>/` 下写代码、记笔记
3. `execute.bat <文件名>` → 编译/运行验证
4. `git add . && git commit -m "..."`
5. `close.bat` → 合并到 dev + 推送 GitHub

### 特殊任务

```
newb.bat -custom test01        → 建 test01 实验分支
（...干活...）
close.bat                      → 正常合并到 dev
```

### 只想删分支，不想合并

```
close.bat -nomerge             → 直接删分支，未提交改动继承到 dev
```

### 只在某个目录里找文件

```
execute.bat hw -d date\20260929-c
```

---

## 四、注意事项 Notes

### ⚠️ 基础构筑工具必须在 dev 分支上修改

**`newb.bat`、`close.bat`、`execute.bat`、`new_venv.bat`、`quit_venv.bat`、`.gitignore`、`.vscode/`、`README.md` 等属于"基础构筑"，必须在 `dev` 分支上修改并提交。**

原因：
- 这些是所有分支共用的工具，不属于任何一天的作业
- 如果在临时分支上修改，`close.bat` 执行 `git checkout dev` 时，**磁盘上的脚本会被 git 换成 dev 版本**
- Windows cmd 执行 bat 时，如果文件被中途修改，会导致执行混乱甚至中断

正确做法：
```
git checkout dev
（修改脚本）
git add . && git commit -m "chore: ..."
git push origin dev
```

### ⚠️ 校园网连不上 GitHub

校园网直连 GitHub 会报 `Failed to connect to port 443` 或 `Connection was reset`。挂梯子也救不了。

**推送 GitHub 时请使用手机热点。**

### 其余网络排查

推 GitHub 超时或 SSL 报错时：
1. 关掉梯子（SSL 证书错误大多是梯子中间人导致）
2. 热点也超时的话可以用 `ipconfig /flushdns`

### VSCode 自动激活 venv 的关闭方法

VSCode 打开终端时会自动检测 `.venv/` 并执行 activate，导致每次开新终端都出现 `(.venv)` 前缀。

**关闭方法**（推荐全局关，一次搞定）：

`Ctrl+Shift+P` → `Preferences: Open User Settings (JSON)` → 加入：

```json
"python.terminal.activateEnvironment": false
```

保存后**关掉所有终端重新打开**，前缀消失。

需要时手动激活：`.venv\Scripts\activate`，或跑 `new_venv.bat`。

### 编码约定

- `.bat` 文件保存为 **GBK**（中文 Windows cmd 默认代码页 936）
- `.md` `.c` `.cpp` `.py` `.json` 等保存为 **UTF-8**
- VS Code 已通过 `.vscode/settings.json` 为 `.bat` 设置默认 GBK

### PAT 使用

- `close.bat` 需要输入 GitHub Personal Access Token (PAT)
- PAT 仅暂存于 `%TEMP%` 下的临时文件，脚本结束时立即删除
- 建议使用 fine-grained token，只授权 `Contents: Read and write`，限定本仓库
- PAT 保存位置：语雀私密文档（已开启二次验证）

---

## 五、目录结构 Directory Layout

```
BPU26/
├── .venv/                    Python 虚拟环境（git 忽略）
├── .vscode/                  VS Code 工作区配置
├── date/                     按日期归档的课堂记录
│   ├── 20260929-c/           2026-09-29 C 语言课
│   │   ├── first.c           第一段代码
│   │   ├── hw.c              课后作业
│   │   ├── note.md           课堂笔记
│   │   └── ...
│   ├── 20260930-ai/          2026-09-30 AI 课
│   │   ├── note.md           课堂笔记
│   │   └── ...               （未来：Python 脚本等）
│   ├── 20261008-c/           2026-10-08 C 语言课
│   │   ├── basic_format_char.c
│   │   ├── basic_format_float.c
│   │   ├── basic_format_int.c
│   │   ├── print_2_num.c
│   │   └── note.md
│   ├── ...
│   └── <yyyyMMdd>-<type>/    后续按此格式递增
│       ├── *.c / *.cpp       C / C++ 源代码
│       ├── *.py              Python 脚本
│       ├── note.md           课堂笔记
│       ├── Makefile          多文件项目时可选用
│       └── ...
├── tools/                    自研工具源码
│   └── repo-tool/            部署工具（见 TODO）
├── release/                  正式版产物索引（exe 本体 gitignore）
│   └── README.md             说明各版本产物
├── .gitignore
├── close.bat
├── execute.bat
├── newb.bat
└── venv.bat
└── README.md
```

### 目录命名规则

- 目录名 = 分支名，形如 `<yyyyMMdd>-<type>`
- `<type>` 取值：`c`（C 语言课）、`ai`（AI 课）、`other`（其他）
- 每个目录下按需放置代码、笔记、作业等
- 目录数量随时间增长，上面仅为格式示例

### 每个目录里可能有什么

| 文件名 | 说明 |
|--------|------|
| `*.c` / `*.cpp` | C / C++ 源代码 |
| `*.py` | Python 脚本 |
| `note.md` | 课堂笔记（Markdown 格式） |
| `note.src.md` | 笔记源文件（含 `@include` / `@run` 占位符，见 TODO） |
| `Makefile` | 多文件项目时的构建脚本（可选） |
| `*.exe` | 编译产物（git 忽略） |

---

## 六、发布正式版 Release Process

当某个版本的 repo-tool 达到"完全可用、无 bug"状态时：

1. 在 Win7 32 位虚拟机测试通过
2. 编译最终 exe：
   ```
   set GOOS=windows
   set GOARCH=386
   go build -o repo-tool.exe .
   ```
3. 把 dev 合并到 main：
   ```
   git checkout main
   git merge dev
   git push origin main
   ```
4. 打 tag：
   ```
   git tag v1.0.0
   git push origin v1.0.0
   ```
5. 打开 GitHub Releases 页面 → 创建 Release
   - 选择 v1.0.0 tag
   - 上传 `repo-tool.exe`
   - 填写发布说明
6. 在 `release/` 目录下创建对应的 `<版本号>.md`，写清此版本的变更、用法、校验和
7. `README.md` 的"目录结构"或单独一节里超链接引用该文件

---

## 七、待办 TODO

### P1：近期

- [ ] **close.bat：pull 失败时中止**
  当前 `git pull --rebase origin dev` 失败会直接 exit，但要检查所有 pull 分支是否一致处理。

### P2：下次做

- [ ] **repo-tool 部署工具**
  - 语言：Go 1.20（Win7 最后支持版本）
  - 编译目标：`GOOS=windows GOARCH=386`，32 位静态链接
  - 功能：一键部署环境 + clone 仓库 / 一键清理（删仓库 + 敏感文件，保留通用工具）
  - 代码位置：`tools/repo-tool/`
  - 产物位置：`release/`，exe 本体 gitignore
  - 部署场景：Win7 32 位机房（校园网、可能无管理员权限、可能禁 USB）
  - 兼容策略：U 盘带离线包，不依赖联网

- [ ] **execute.bat 支持多文件项目**
  - 判定依据：目标文件所在目录是否存在 Makefile
  - 有 Makefile → 调 `make run`（约定 Makefile 里定义 run 目标）
  - 无 Makefile → 现有 gcc/g++ 单文件逻辑
  - 已知不足：多文件但未写 Makefile 的项目会被误判为单文件，后续再优化特征判定

- [ ] **sync-notes 工具**
  - 目的：自动把代码 + 运行结果同步进 note.md，避免手动复制
  - 语法：`note.src.md` 中用 `<!-- @include: file.c -->` 和 `<!-- @run: name -->`
  - 工具展开后生成 `note.md`
  - 调用链：`close.bat → sync-notes.bat → execute.bat`
  - 失败策略：任何一个 `@run` 编译失败，整体中止，不写入 note.md（原子性）
  - 预留参数：`--no-run`（暂不实现，遇到时报错退出）

### P3：远期

- [ ] 补全历史项目的 README
- [ ] 考虑 sync-notes 的缓存优化（时间戳判断，避免每次重跑）

---

_最后更新：2026-10-08_