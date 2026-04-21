# Mac Fleet Control 🖥️

![GitHub stars](https://img.shields.io/github/stars/willau95/mac-fleet-control)
![GitHub license](https://img.shields.io/github/license/willau95/mac-fleet-control)
![GitHub last commit](https://img.shields.io/github/last-commit/willau95/mac-fleet-control)

> ⚠️ **本软件按"原样"提供，不含任何保证。您需自行承担授权、合规和安全责任。详见 [SECURITY.md](SECURITY.md)。**

中文 | **[English](README.md)**

**一条命令让任何 Mac 远程完全控制另一台 Mac。零配置网络，端到端加密。**

终端命令 · 浏览器自动化 · 鼠标键盘 · 屏幕截图 · VNC 远程桌面 — 全部支持。

---

## 📋 前置条件（新电脑用户请先看这里）

跑本 repo 任何脚本之前，**每一台**你打算加入 fleet 的 Mac（无论 master 还是 worker）都必须先满足下面的条件。整个准备工作每台机器只需一次，约 5 分钟。完成之后，剩下的全部自动化。

### 你需要什么

| | 要求 |
|---|------|
| **硬件** | 任何 Mac（Intel 或 Apple Silicon），近 10 年的机器都行 |
| **系统** | macOS 12 Monterey 或更新（更老的系统可能能跑但没测过） |
| **磁盘** | ~5 GB 可用空间（主要是 Xcode CLT + Homebrew + Playwright） |
| **网络** | 任何能上网的连接 — 4G 热点、NAT 后面、不同 WiFi 都行。Tailscale 自动处理 NAT 穿透。 |
| **账号** | 一个免费的 Tailscale 账号（在 https://tailscale.com 注册，用 Google/Apple/Microsoft/GitHub 登录都行）。**Fleet 里所有 Mac 必须用同一个 Tailscale 账号。** |
| **管理员密码** | 装机过程中会用到几次 macOS 登录密码（sudo、开 Remote Login、授权权限）。 |

### A 步 — 打开 Terminal

如果你从来没用过 Terminal：按 `⌘ + Space` → 输入 `Terminal` → 回车。

会弹出一个黑/白色窗口 — 后面所有命令都在这里粘贴运行。窗口里**右键**就能粘贴，按回车执行。

> **新 Mac 注意：** 第一次跑开发命令（比如 `git`）时，macOS 会弹一个对话框要你装 **Xcode Command Line Tools**。你可以现在就点 Install 装掉，也可以不管它 — 后面 `worker-setup.sh` 会在后台自动触发安装。

### B 步 — 在每一台 Mac 上装 Tailscale

Tailscale 是把所有 Mac 安全连接起来的网络层。**每一台机器都要装**（master + 每一台 worker）。下面**二选一**，脚本两种安装方式都自动识别。

#### 方式 1（推荐）—— App Store GUI 版

最适合 fleet 上长期在线的机器。原生的开机自启、自动更新、系统权限对话框都自带。

1. 打开 App Store → 搜索 **Tailscale** → 安装
   *（直接链接：https://apps.apple.com/app/tailscale/id1475387142）*

2. 打开 Tailscale（它会出现在屏幕**右上角菜单栏**，是一个小图标）

3. 点菜单栏的 Tailscale 图标 → **Log in** → 选你的登录方式（Google / Apple / Microsoft / GitHub / email）

4. **关键：** 每台 Mac 必须登录到**同一个** Tailscale 账号，否则它们看不到对方。

5. 验证已连接：菜单栏图标不应有斜杠。要双重确认，开 Terminal 跑：
   ```bash
   /Applications/Tailscale.app/Contents/MacOS/Tailscale ip -4
   ```
   你应该看到一个 `100.x.x.x` 开头的 IP（这是 Tailscale 分配的）。

#### 方式 2 —— Homebrew CLI 版

适合终端党或不想要菜单栏 app 的机器。需要多一步手动操作（启动 daemon、浏览器里点登录）。

1. 先装 Homebrew（如果还没装）：
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. 通过 Homebrew 装 Tailscale，有两种装法：
   - **纯 CLI daemon**（无头机器 / 服务器）：
     ```bash
     brew install tailscale
     sudo brew services start tailscale
     ```
   - **Cask 菜单栏版**（和 App Store 版一样）：
     ```bash
     brew install --cask tailscale-app
     ```

3. 登录：
   ```bash
   tailscale up
   ```
   会输出一个认证 URL — 在浏览器打开并登录。**所有 Mac 登同一个** Tailscale 账号。

4. 验证：
   ```bash
   tailscale ip -4
   ```
   应该看到 `100.x.x.x` 开头的 IP。

> **App Store 版 vs. Homebrew 版，怎么选？** App Store GUI 版开机自启、自动更新、系统权限对话框原生处理，最适合长期无人值守的 fleet worker。Homebrew CLI 版更轻量、更脚本化，但你得用 `brew services` 管 daemon，重新认证后要再跑 `tailscale up`。两种本项目都完全支持 —— 脚本自动检测两种安装位置（`/Applications/Tailscale.app/...` 或 `/opt/homebrew/bin/tailscale`）。按你的工作流选就行。

### C 步 — 登录 https://login.tailscale.com 检查（推荐）

在几台 Mac 都登录 Tailscale 之后，访问 https://login.tailscale.com/admin/machines。你应该能看到这些机器列在那里。这里也是后续移除机器、分享给别人、查看状态的地方。**收藏这个页面**。

### 你不需要手动装的东西

下面这些脚本会全部自动处理 — 列在这里只是让你知道大致流程：

- ❌ **Homebrew** — `worker-setup.sh` 自动装。如果已经装过但 `brew` 提示 `command not found`，脚本自动修复 PATH。
- ❌ **Node.js / npm** — 通过 Homebrew 自动装。
- ❌ **Playwright + 浏览器** — 自动装（用 `chromium-headless-shell`，~70 MB）。
- ❌ **cliclick**（鼠标/键盘自动化）— 通过 Homebrew 自动装。
- ❌ **Xcode Command Line Tools** — `worker-setup.sh` 在 Step 0 后台异步触发非交互式安装，和其他步骤并行进行，节省 ~10–20 分钟体感等待时间。如果系统弹出对话框，点 **Install** 即可。
- ❌ **SSH 密钥** — 自动生成并交换。

---

## 🚀 极速上手（前置条件做完后，3 步搞定）

### 第 1 步 — 在你的第一台 Mac 上（这台就是 **master**）

```bash
git clone https://github.com/willau95/mac-fleet-control.git ~/mac-fleet-control \
  && cd ~/mac-fleet-control \
  && bash master-setup.sh
```

### 第 2 步 — 在 master 上拿到 worker 的安装命令

```bash
fleet-ssh master
```

会输出一条**完整可粘贴**的命令，例如：

```bash
git clone https://github.com/willau95/mac-fleet-control.git ~/mac-fleet-control \
  && cd ~/mac-fleet-control \
  && bash worker-setup.sh --master seacapital@100.107.142.39
```

### 第 3 步 — 在每一台你想控制的 Mac（worker）上

把第 2 步的命令粘进 worker 的终端。脚本会自动：
- ✅ 装 Homebrew（已装但 PATH 没配的话自动修复）
- ✅ 装 Node.js + Playwright（chromium-headless-shell, ~70 MB）
- ✅ 在后台异步触发 Xcode CLT 安装（节省 ~15 分钟）
- ✅ 双向配置 SSH 免密 — 只问 master 密码**一次**
- ✅ 自动注册到 master 的 fleet
- ✅ 自检验证全部就绪

**完事**。回 master 跑 `fleet-ssh list`，新 worker 已 online。

> **可选第 4 步 — 让 worker 永远在线：** `bash worker-harden.sh`（禁睡眠、自动登录、自愈 watchdog）。详见下方 [Hardening](#步骤-3加固永远在线)。

---

## 架构

```
Master A ──┐                                ┌── Worker 1
Master B ──┤── Tailscale (WireGuard 加密) ──┼── Worker 2
Master C ──┘     任何网络都能连              └── Worker N
```

- ✅ 多 Master 天然支持
- ✅ 一台机器可以同时是 Master 和 Worker
- ✅ WireGuard 端到端加密
- ✅ 不暴露公网端口
- ✅ 换 WiFi / 换地点 / 4G 热点都能连
- ✅ 自愈 Watchdog 每 5 分钟自动修复

---

## 详细设置参考

### 多个 Master

一个 worker 可以同时注册到多个 master：

```bash
bash worker-setup.sh --master john@100.x.x.x --master jane@100.y.y.y
```

### worker-setup.sh 内部都做了什么

| # | 步骤 | 说明 |
|---|------|------|
| 0 | 后台异步触发 Xcode CLT 安装 | 节省 ~10–20 分钟（不让 brew 串行触发） |
| 1 | 验证 Tailscale 已连接 | 没连就退出并给提示 |
| 2 | 开启 macOS Remote Login (SSH) | 通过 `systemsetup` |
| 3 | 生成 SSH key + 配置 | 加 `IdentitiesOnly` 防 auth-flood 错误 |
| 4 | 安装 Homebrew + 自动修复 PATH + cliclick + Node + Playwright | **自动修复"brew 装了但 PATH 没配"的常见坑** |
| 5 | 创建 fleet-tools (`screenshot-url.js`, `browser-action.js`, `capture-screen.sh`) | 在 `~/fleet-tools/` |
| 6 | 双向交换 SSH key + 注册到 master | Master 密码只问**一次** |
| 7 | 输出还需要手动授权的 3 个权限（见下） | 一次性，重启不丢 |

### 步骤 2：手动设权限（一次性，1分钟）

在 Worker Mac 上打开 **System Settings**：

#### ① Screen Sharing（远程桌面）
> System Settings → General → Sharing → **Screen Sharing → ON**

#### ② Screen Recording（远程截图）
> System Settings → Privacy & Security → **Screen & System Audio Recording**
> → 点 **+** → 加这 2 个：
> - **`/usr/libexec/sshd-keygen-wrapper`** — 按 **Cmd+Shift+G** 粘贴路径
> - **`Tailscale.app`** — 进 `/Applications/`，选中整个 app *(不要进去找 binary)*
>
> *(如果你装的是 Homebrew 版 Tailscale 而非 App Store 版，把第二项换成 `/opt/homebrew/opt/tailscale/bin/tailscaled`)*

#### ③ Accessibility（远程鼠标/键盘）
> System Settings → Privacy & Security → **Accessibility**
> → 点 **+** → 加同样的 2 个：
> - **`/usr/libexec/sshd-keygen-wrapper`**
> - **`Tailscale.app`**（Homebrew 版用 `tailscaled`）

**这 3 个权限重启不丢，只需设一次。**

### 步骤 3：加固（永远在线）

```bash
bash worker-harden.sh
```

会问一次 macOS 密码（设自动登录用），其余全自动。

**加固后效果：**
| 设置 | 效果 |
|------|------|
| 禁止睡眠/休眠 | 永远不睡 |
| Wake on LAN | 局域网可唤醒 |
| 停电自动重启 | 来电自动开机 |
| Tailscale 开机自启 | 重启后自动连上 |
| 自动登录 | 重启后直接进桌面 |
| 禁止自动更新 | 不会半夜自己重启 |
| 禁止屏幕锁 | 不会要求输密码 |
| 自愈 Watchdog | 每 5 分钟检查，自动修复 |

---

## 使用（在 Master 上）

### 基本命令

```bash
# 查看所有机器
fleet-ssh list

# 在 master 上输出"加新 worker"的可粘贴命令
fleet-ssh master

# Ping 测速
fleet-ssh ping

# 用编号执行命令
fleet-ssh 1 "hostname && uptime"

# 用名字执行（支持部分匹配）
fleet-ssh seas "hostname"

# 所有机器执行
fleet-ssh all "uptime"

# 进入远程终端
fleet-ssh shell 1

# 手动添加/删除机器
fleet-ssh add "名字" "user" "ip"
fleet-ssh remove "名字"
```

### 手动添加一台机器

如果一台机器已经装好了，但不在你的 fleet 里（比如把一台 Master 加到另一台 Master 的 fleet），只需两步：

**第 1 步：** 注册机器
```bash
fleet-ssh add "Office-iMac" "john" "100.x.x.x"
```

**第 2 步：** 配置免密 SSH（只需一次，会要求输入一次密码）
```bash
ssh-copy-id john@100.x.x.x
```

搞定。`fleet-ssh list` 应该就能看到它 online 了。

> **说明：** `worker-setup.sh` 会自动完成以上两步。手动添加只在跳过安装脚本时才需要（比如把一台已有的 Master 作为 Worker 加到另一台 Master 的 fleet）。

### 鼠标/键盘控制

```bash
fleet-ssh 1 "cliclick m:500,500"           # 移动鼠标
fleet-ssh 1 "cliclick c:500,500"           # 单击
fleet-ssh 1 "cliclick dc:500,500"          # 双击
fleet-ssh 1 "cliclick rc:500,500"          # 右键
fleet-ssh 1 "cliclick t:'Hello World'"     # 打字
fleet-ssh 1 "cliclick kp:command-a"        # 快捷键 Cmd+A
fleet-ssh 1 "cliclick kp:command-c"        # Cmd+C
fleet-ssh 1 "cliclick kp:command-v"        # Cmd+V
fleet-ssh 1 "cliclick kp:return"           # 回车
```

### 截图

```bash
# 屏幕截图
fleet-ssh 1 "bash ~/fleet-tools/capture-screen.sh /tmp/screen.png"

# 网页截图
fleet-ssh 1 "node ~/fleet-tools/screenshot-url.js https://google.com /tmp/google.png"

# 拉回截图到本地
scp user@ip:/tmp/screen.png ~/Desktop/
```

### 浏览器自动化

```bash
# 打开网页 + 执行操作
fleet-ssh 1 "node ~/fleet-tools/browser-action.js '{
  \"url\": \"https://google.com\",
  \"actions\": [
    {\"type\": \"click\", \"selector\": \"textarea[name=q]\"},
    {\"type\": \"type\", \"selector\": \"textarea[name=q]\", \"text\": \"hello\"},
    {\"type\": \"screenshot\", \"path\": \"/tmp/result.png\"}
  ]
}'"
```

### VNC 远程桌面

```bash
open vnc://user@<worker-tailscale-ip>
```

---

## 一台机器同时做 Master 和 Worker

完全支持，分别跑：

```bash
bash master-setup.sh                              # 作为 Master
bash worker-setup.sh --master other@100.x.x.x     # 作为 Worker
bash worker-harden.sh                              # 加固
```

---

## 已部署机器更新

### TL;DR — 单台 master 更新（一条命令搞定）

在任何一台需要更新的 master 上跑：

```bash
cd ~/mac-fleet-control && git pull origin main && sudo cp fleet-ssh /usr/local/bin/fleet-ssh && fleet-ssh master
```

末尾那个 `fleet-ssh master` 顺便验证新版本是否生效 — 如果输出的是可粘贴的 worker 安装命令块，说明 `fleet-ssh` 已经是最新的。如果看到旧版的 `Usage: fleet-ssh <target>...` 错误，去下面**「常见坑：PATH 遮蔽问题」**那一段修。

---

当 repo 有新版本时，按角色更新：

### 第 1 步：更新所有 Worker（在任意 Master 上跑一次）

```bash
fleet-ssh all "cd ~/mac-fleet-control && git fetch origin && git reset --hard origin/main"
```

一条命令更新整个 fleet。

### 第 2 步：更新每台 Master

在每台 **Master 机器**上本地跑（包括同时是 Master + Worker 的机器）：

```bash
cd ~/mac-fleet-control && git fetch origin && git reset --hard origin/main
sudo cp fleet-ssh /usr/local/bin/fleet-ssh
```

`sudo cp` 这步是必须的 — `fleet-ssh` 安装在 `/usr/local/bin/`，单纯 git pull 不会更新它。

> ⚠️ **常见坑：「我更新了，但 `fleet-ssh` 还是旧版的行为」**
>
> 有些机器在 PATH 里有**多份** `fleet-ssh`（`~/bin/`、`~/.local/bin/`、`/usr/local/bin/`）。Shell 调用的是 PATH 里**最先找到**的那份，可能正好遮住你刚更新的那份。检查方法：
>
> ```bash
> type -a fleet-ssh
> ```
>
> 如果看到多于一个路径，把其它的全部改成**软链**指向标准位置，以后更新自动同步：
>
> ```bash
> rm ~/bin/fleet-ssh ~/.local/bin/fleet-ssh 2>/dev/null
> ln -s /usr/local/bin/fleet-ssh ~/bin/fleet-ssh
> ln -s /usr/local/bin/fleet-ssh ~/.local/bin/fleet-ssh
> ```
>
> 之后你的更新流程就是一条命令：`cd ~/mac-fleet-control && git pull && sudo cp fleet-ssh /usr/local/bin/fleet-ssh` — 所有 PATH 入口同步看到新版。

### 速查表

| 角色 | 命令 | 在哪跑 |
|------|------|--------|
| 所有 Worker | `fleet-ssh all "cd ~/mac-fleet-control && git fetch origin && git reset --hard origin/main"` | 任意 Master |
| 每台 Master | `cd ~/mac-fleet-control && git fetch origin && git reset --hard origin/main && sudo cp fleet-ssh /usr/local/bin/fleet-ssh` | 本地 |

### 重新跑脚本（可选，仅当安装流程有变更时）

所有脚本都是幂等设计，重复跑不会出问题：

```bash
bash worker-setup.sh --master user@ip
bash worker-harden.sh
bash master-setup.sh
```

---

## 检查与诊断

### 快速检查清单

```bash
# Master: 查看所有机器状态
fleet-ssh list

# Master: 批量检查
fleet-ssh all "hostname && tailscale ip -4 && uptime"

# Worker: 检查 Tailscale
tailscale status

# Worker: 检查 SSH
sudo systemsetup -getremotelogin

# Worker: 检查睡眠设置
pmset -g | grep sleep

# Worker: 检查 Watchdog
launchctl list | grep fleet.watchdog

# Worker: 查看 Watchdog 日志
tail -20 ~/fleet-tools/watchdog.log

# Worker: 检查所有工具
which cliclick node npm && ls ~/fleet-tools/
```

### fleet-ssh list 显示 timeout

**原因：** SSH key 没配好。

**解决：** 在 Master 上跑：
```bash
ssh-copy-id <worker-user>@<worker-tailscale-ip>
```
输入 Worker 密码一次，之后永久免密。

### fleet-ssh list 显示 offline

**原因 1：** Worker 的 Tailscale 没连上。
**解决：** 去 Worker 上打开 Tailscale app，确保已连接。

**原因 2：** Worker 关机或睡眠了。
**解决：** 跑 `bash worker-harden.sh` 禁止睡眠 + 设自动重启。

**原因 3：** Worker 的 SSH 没开。
**解决：** 在 Worker 上跑：
```bash
sudo systemsetup -f -setremotelogin on
```

### 截图失败 (Screen capture failed)

**原因：** Screen Recording 权限没加 `sshd-keygen-wrapper`。

**解决：**
> System Settings → Privacy & Security → Screen & System Audio Recording
> → 加 `/usr/libexec/sshd-keygen-wrapper`

### cliclick 没反应 / 鼠标不动

**原因：** Accessibility 权限没加 `sshd-keygen-wrapper`。

**解决：**
> System Settings → Privacy & Security → Accessibility
> → 加 `/usr/libexec/sshd-keygen-wrapper`

### Too many authentication failures

**原因：** SSH 尝试了太多 key。

**解决：** 脚本已自动修复（IdentitiesOnly）。如果还出现：
```bash
echo -e "\nHost *\n  IdentitiesOnly yes\n  IdentityFile ~/.ssh/id_ed25519" >> ~/.ssh/config
```

### Tailscale 重启后没自动连上

**原因：** Tailscale 没设开机自启。

**解决：** 跑 `bash worker-harden.sh`，或手动：
- App Store 版：System Settings → General → Login Items → 加 Tailscale
- Brew 版：`brew services start tailscale`

### Worker 重启后卡在登录界面

**原因：** 没设自动登录。

**解决：** 跑 `bash worker-harden.sh`，或手动：
> System Settings → Users & Groups → Automatic Login → 选择用户

### node/cliclick command not found

**原因：** SSH 环境没加载 Homebrew PATH。

**解决：** `fleet-ssh` 已自动处理。如果直接 SSH 遇到，跑：
```bash
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
```

### Playwright / 网页截图失败

**原因：** Playwright 没装好。

**解决：** 在 Worker 上跑：
```bash
cd ~/fleet-tools && npm install playwright && npx playwright install chromium
```

### VNC 连不上

**原因：** Worker 没开 Screen Sharing。

**解决：**
> System Settings → General → Sharing → Screen Sharing → ON

### Worker 被带到别的网络后连不上

**原因：** 极端企业网络可能阻断 Tailscale。

**解决：** 大部分网络（家庭/咖啡厅/手机热点）都没问题。如果是企业防火墙：
1. 试试用手机热点连
2. 确认 Tailscale app 显示已连接
3. Watchdog 会每 5 分钟自动尝试重连

---

## 文件说明

| 文件 | 用途 |
|------|------|
| `master-setup.sh` | Master 设置（检查环境 + 装 fleet-ssh + 初始化注册表） |
| `worker-setup.sh` | Worker 设置（装工具 + SSH 免密码 + 自动注册到 Master） |
| `worker-harden.sh` | Worker 加固（永远在线 + 自愈 Watchdog） |
| `fleet-ssh` | 批量控制工具（list/ping/shell/run） |
| `SOP.md` | 完整操作手册 |
| `fleet-tools-example.md` | 远程操作示例集 |

### Worker 上生成的文件

| 路径 | 用途 |
|------|------|
| `~/fleet-tools/capture-screen.sh` | 屏幕截图脚本 |
| `~/fleet-tools/screenshot-url.js` | 网页截图脚本 |
| `~/fleet-tools/browser-action.js` | 浏览器自动化脚本 |
| `~/fleet-tools/fleet-watchdog.sh` | 自愈 Watchdog 脚本 |
| `~/fleet-tools/watchdog.log` | Watchdog 日志 |

### Master 上的文件

| 路径 | 用途 |
|------|------|
| `~/.fleet-machines.json` | 机器注册表 |
| `/usr/local/bin/fleet-ssh` | fleet-ssh 命令 |

---

## 安全说明

- 所有通信经 Tailscale WireGuard 加密，不暴露公网端口
- SSH 使用 ED25519 key，无密码暴力破解风险
- Tailscale ACL 可限制哪些机器能互访
- `worker-harden.sh` 关闭了屏幕锁和自动更新 — 适用于受控环境，不建议用于公共场合的个人电脑

---

## 跨账号控制（Worker 用不同 Tailscale 账号）

默认所有机器用同一个 Tailscale 账号，最简单最可靠。但如果 Worker 必须用不同账号（例如客户/合作方的设备），可以用 **Tailscale Node Sharing**：

### 设置步骤

1. **Worker 方**：用自己的 Tailscale 账号登录，正常连接
2. **Master 方**：打开 Tailscale Admin Console → https://login.tailscale.com/admin/machines
3. 找到 Worker 的设备 → 点 **"..."** → **Share**
4. 输入 Master 方的 Tailscale 账号邮箱
5. **Master 方**：在 Admin Console 接受共享邀请
6. 此时两边网络互通，正常跑 `worker-setup.sh` 即可

### 注意事项

- 共享后 Worker 会出现在 Master 的 `tailscale status` 里，有独立 IP
- 双方都可以随时取消共享
- **风险**：如果对方退出 Tailscale 登录或取消共享，你就失联了
- **建议**：对于需要 100% 可控的设备（员工/托管），优先用统一账号

详细文档：https://tailscale.com/kb/1084/sharing

---

## License

MIT
