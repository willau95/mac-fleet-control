# Mac Fleet Control 🖥️

> ⚠️ **本软件按"原样"提供，不含任何保证。您需自行承担授权、合规和安全责任。详见 [SECURITY.md](SECURITY.md)。**

中文 | **[English](README.md)**

**一条命令让任何 Mac 远程完全控制另一台 Mac。零配置网络，端到端加密。**

终端命令 · 浏览器自动化 · 鼠标键盘 · 屏幕截图 · VNC 远程桌面 — 全部支持。

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

## 前置条件（手动，一次性）

**每台机器都要做：**

1. **安装 Tailscale**（推荐 App Store 版，更稳定可靠）：
   - https://apps.apple.com/app/tailscale/id1475387142

2. **打开 Tailscale** → 登录同一个账号 → 确保显示已连接

3. **安装 Homebrew**（如果没有）:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

4. **安装 Node.js**（如果没有）:
   ```bash
   brew install node
   ```

---

## Master 设置（控制方）

在需要**控制别人**的 Mac 上跑：

```bash
git clone https://github.com/celestwong0920/mac-fleet-control.git ~/mac-fleet-control
cd ~/mac-fleet-control
bash master-setup.sh
```

完成后记住输出的信息，例如：
```
bash worker-setup.sh --master john@100.x.x.x
```

**就这样，Master 设置完成。**

---

## Worker 设置（被控方）

### 步骤 1：跑脚本

在需要**被控制**的 Mac 上跑（把 `--master` 换成上面 Master 输出的值）：

```bash
git clone https://github.com/celestwong0920/mac-fleet-control.git ~/mac-fleet-control
cd ~/mac-fleet-control
bash worker-setup.sh --master <master用户名>@<master的tailscale-ip>
```

例如：
```bash
bash worker-setup.sh --master john@100.x.x.x
```

多个 Master：
```bash
bash worker-setup.sh --master john@100.x.x.x --master jane@100.y.y.y
```

**脚本会自动：**
- ✅ 检查 Tailscale 连接
- ✅ 开启 SSH
- ✅ 安装 cliclick（鼠标/键盘）+ Playwright（浏览器）
- ✅ 创建 fleet-tools 工具包
- ✅ 双向配置 SSH 免密码
- ✅ 自动注册到 Master 的 fleet
- ✅ 验证 Master 能连回来
- ✅ 结尾 Self-Test 检查所有工具

**过程中会问一次 Master 密码，输入后永久免密。**

### 步骤 2：手动设权限（一次性，1分钟）

在 Worker Mac 上打开 **System Settings**：

#### ① Screen Sharing（远程桌面）
> System Settings → General → Sharing → **Screen Sharing → ON**

#### ② Screen Recording（远程截图）
> System Settings → Privacy & Security → **Screen & System Audio Recording**
> → 点 **+** → 按 **Cmd+Shift+G** → 加这 2 个路径：
> ```
> /usr/libexec/sshd-keygen-wrapper
> /opt/homebrew/opt/tailscale/bin/tailscaled
> ```

#### ③ Accessibility（远程鼠标/键盘）
> System Settings → Privacy & Security → **Accessibility**
> → 点 **+** → 按 **Cmd+Shift+G** → 加这 2 个路径：
> ```
> /usr/libexec/sshd-keygen-wrapper
> /opt/homebrew/opt/tailscale/bin/tailscaled
> ```

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

当 repo 有新版本时，在每台机器上跑：

```bash
cd ~/mac-fleet-control && git pull
```

或者从 Master 远程批量更新：

```bash
fleet-ssh all "cd ~/mac-fleet-control && git pull"
```

重新跑脚本（安全，幂等设计）：

```bash
# Worker 重跑
bash worker-setup.sh --master user@ip
bash worker-harden.sh

# Master 重跑
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
