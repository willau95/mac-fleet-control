# Mac Fleet Control 🖥️

![GitHub stars](https://img.shields.io/github/stars/willau95/mac-fleet-control)
![GitHub license](https://img.shields.io/github/license/willau95/mac-fleet-control)
![GitHub last commit](https://img.shields.io/github/last-commit/willau95/mac-fleet-control)

> ⚠️ **This software is provided "AS IS" without warranty. You are solely responsible for authorization, compliance, and security. See [SECURITY.md](SECURITY.md) for full disclaimer.**

**[中文文档](README_CN.md)** | English

**One command to fully control any Mac remotely.** Zero-config networking, end-to-end encrypted.

Terminal commands · Browser automation · Mouse & keyboard · Screenshots · VNC remote desktop — all supported.

---

## Architecture

```
Master A ──┐                                ┌── Worker 1
Master B ──┤── Tailscale (WireGuard E2EE) ──┼── Worker 2
Master C ──┘    Works on any network        └── Worker N
```

- ✅ Multi-master support
- ✅ One machine can be both Master and Worker
- ✅ WireGuard end-to-end encryption
- ✅ No public ports exposed
- ✅ Works across WiFi changes / locations / mobile hotspots
- ✅ Self-healing watchdog (auto-fixes every 5 min)

---

## Prerequisites (manual, one-time)

**On every machine (only 2 manual steps):**

1. **Install Tailscale** from the App Store (recommended for reliability):
   - https://apps.apple.com/app/tailscale/id1475387142

2. **Open Tailscale** → Log in with the same account → Ensure it shows connected

> Homebrew and Node.js are installed (and added to PATH) automatically by `worker-setup.sh` — no manual setup needed. If Homebrew was already installed but `brew` says `command not found`, the script auto-fixes the PATH for you.

---

## Master Setup (controller)

Run on any Mac that needs to **control other Macs**:

```bash
git clone https://github.com/celestwong0920/mac-fleet-control.git ~/mac-fleet-control
cd ~/mac-fleet-control
bash master-setup.sh
```

Note the output, e.g.:
```
bash worker-setup.sh --master john@100.x.x.x
```

**That's it. Master is ready.**

---

## Worker Setup (controlled machine)

### Step 1: Run the script

Run on any Mac that needs to **be controlled** (replace `--master` with the value from master setup):

```bash
git clone https://github.com/celestwong0920/mac-fleet-control.git ~/mac-fleet-control
cd ~/mac-fleet-control
bash worker-setup.sh --master <master-user>@<master-tailscale-ip>
```

Example:
```bash
bash worker-setup.sh --master john@100.x.x.x
```

Multiple masters:
```bash
bash worker-setup.sh --master john@100.x.x.x --master jane@100.y.y.y
```

**The script automatically:**
- ✅ Checks Tailscale connection
- ✅ Enables SSH
- ✅ Installs cliclick (mouse/keyboard) + Playwright (browser)
- ✅ Creates fleet-tools toolkit
- ✅ Sets up bidirectional SSH key auth
- ✅ Auto-registers to master's fleet
- ✅ Verifies master can connect back
- ✅ Runs self-test at the end

**Will ask for master's password once — permanent passwordless access after that.**

### Step 2: Manual permissions (one-time, 1 minute)

On the Worker Mac, open **System Settings**:

#### ① Screen Sharing (remote desktop)
> System Settings → General → Sharing → **Screen Sharing → ON**

#### ② Screen Recording (remote screenshots)
> System Settings → Privacy & Security → **Screen & System Audio Recording**
> → Click **+** → add these 2 entries:
> - **`/usr/libexec/sshd-keygen-wrapper`** — press **Cmd+Shift+G** to paste
> - **`Tailscale.app`** — navigate to `/Applications/`, select the app *(do not go inside it)*
>
> *(If you installed Tailscale via Homebrew instead of the App Store, add `/opt/homebrew/opt/tailscale/bin/tailscaled` instead of `Tailscale.app`.)*

#### ③ Accessibility (remote mouse/keyboard)
> System Settings → Privacy & Security → **Accessibility**
> → Click **+** → add the same 2 entries as above:
> - **`/usr/libexec/sshd-keygen-wrapper`**
> - **`Tailscale.app`** (or `tailscaled` if Homebrew install)

**These 3 permissions survive reboots — truly one-time.**

### Step 3: Hardening (always online)

```bash
bash worker-harden.sh
```

Will ask for macOS password once (for auto-login setup), everything else is automatic.

**After hardening:**
| Setting | Effect |
|---------|--------|
| Disable sleep/hibernation | Never sleeps |
| Wake on LAN | Can be woken via network |
| Auto-restart on power failure | Powers on when electricity returns |
| Tailscale auto-start | Reconnects after reboot |
| Auto-login | Goes straight to desktop after reboot |
| Disable auto-updates | Won't restart unexpectedly |
| Disable screen lock | No password prompt on wake |
| Self-healing watchdog | Checks & fixes every 5 minutes |

---

## Usage (on Master)

### Basic commands

```bash
# List all machines
fleet-ssh list

# Ping all
fleet-ssh ping

# Run command by number
fleet-ssh 1 "hostname && uptime"

# Run by name (partial match)
fleet-ssh my-imac "hostname"

# Run on ALL machines
fleet-ssh all "uptime"

# Interactive SSH session
fleet-ssh shell 1

# Add/remove machines manually
fleet-ssh add "name" "user" "ip"
fleet-ssh remove "name"
```

### Manually adding a machine

If a machine is already set up but not in your fleet (e.g. adding a master to another master's fleet), do these 2 steps:

**Step 1:** Register it
```bash
fleet-ssh add "Office-iMac" "john" "100.x.x.x"
```

**Step 2:** Set up passwordless SSH (one-time, will ask for password once)
```bash
ssh-copy-id john@100.x.x.x
```

Done. `fleet-ssh list` should now show it as online.

> **Note:** `worker-setup.sh` does both steps automatically. Manual adding is only needed when you skip the setup script (e.g. adding an existing master as a worker to another master).

### Mouse & keyboard control

```bash
fleet-ssh 1 "cliclick m:500,500"           # Move mouse
fleet-ssh 1 "cliclick c:500,500"           # Click
fleet-ssh 1 "cliclick dc:500,500"          # Double click
fleet-ssh 1 "cliclick rc:500,500"          # Right click
fleet-ssh 1 "cliclick t:'Hello World'"     # Type text
fleet-ssh 1 "cliclick kp:command-a"        # Shortcut Cmd+A
fleet-ssh 1 "cliclick kp:command-c"        # Cmd+C
fleet-ssh 1 "cliclick kp:command-v"        # Cmd+V
fleet-ssh 1 "cliclick kp:return"           # Enter
```

### Screenshots

```bash
# Screen capture
fleet-ssh 1 "bash ~/fleet-tools/capture-screen.sh /tmp/screen.png"

# Web page screenshot
fleet-ssh 1 "node ~/fleet-tools/screenshot-url.js https://google.com /tmp/google.png"

# Pull screenshot to local machine
scp user@ip:/tmp/screen.png ~/Desktop/
```

### Browser automation

```bash
fleet-ssh 1 "node ~/fleet-tools/browser-action.js '{
  \"url\": \"https://google.com\",
  \"actions\": [
    {\"type\": \"click\", \"selector\": \"textarea[name=q]\"},
    {\"type\": \"type\", \"selector\": \"textarea[name=q]\", \"text\": \"hello\"},
    {\"type\": \"screenshot\", \"path\": \"/tmp/result.png\"}
  ]
}'"
```

### VNC remote desktop

```bash
open vnc://user@<worker-tailscale-ip>
```

---

## One Machine as Both Master and Worker

Fully supported. Run both:

```bash
bash master-setup.sh                              # As master
bash worker-setup.sh --master other@100.x.x.x     # As worker
bash worker-harden.sh                              # Harden
```

---

## Updating Deployed Machines

When the repo has updates, follow these steps based on each machine's role:

### Step 1: Update all workers (run once from any master)

```bash
fleet-ssh all "cd ~/mac-fleet-control && git fetch origin && git reset --hard origin/main"
```

This updates every worker in your fleet with one command.

### Step 2: Update each master

On every machine that acts as a **master** (including machines that are both master and worker), run locally:

```bash
cd ~/mac-fleet-control && git fetch origin && git reset --hard origin/main
sudo cp fleet-ssh /usr/local/bin/fleet-ssh
```

The `sudo cp` step is required because `fleet-ssh` is installed to `/usr/local/bin/` — `git pull` alone won't update it.

### Quick reference

| Role | Command | Where to run |
|------|---------|-------------|
| All workers | `fleet-ssh all "cd ~/mac-fleet-control && git fetch origin && git reset --hard origin/main"` | Any master |
| Each master | `cd ~/mac-fleet-control && git fetch origin && git reset --hard origin/main && sudo cp fleet-ssh /usr/local/bin/fleet-ssh` | Locally on that master |

### Re-run scripts (optional, only if setup changed)

Safe to run again — all scripts are idempotent:

```bash
bash worker-setup.sh --master user@ip
bash worker-harden.sh
bash master-setup.sh
```

---

## Diagnostics & Troubleshooting

### Quick checks

```bash
# Master: list all machines
fleet-ssh list

# Master: batch check
fleet-ssh all "hostname && tailscale ip -4 && uptime"

# Worker: check Tailscale
tailscale status

# Worker: check SSH
sudo systemsetup -getremotelogin

# Worker: check sleep
pmset -g | grep sleep

# Worker: check watchdog
launchctl list | grep fleet.watchdog
tail -20 ~/fleet-tools/watchdog.log
```

### Common issues

| Problem | Cause | Solution |
|---------|-------|----------|
| `fleet-ssh list` shows **timeout** | SSH key not set up | `ssh-copy-id user@worker-ip` on master |
| `fleet-ssh list` shows **offline** | Tailscale disconnected / machine asleep | Open Tailscale app; run `worker-harden.sh` |
| Screenshot fails | Missing Screen Recording permission | Add `sshd-keygen-wrapper` to Screen Recording |
| Mouse doesn't move | Missing Accessibility permission | Add `sshd-keygen-wrapper` to Accessibility |
| Too many auth failures | SSH trying too many keys | Script auto-fixes; or add `IdentitiesOnly yes` to `~/.ssh/config` |
| Tailscale not auto-starting | Not in Login Items | Run `worker-harden.sh` |
| Stuck at login screen after reboot | Auto-login not set | Run `worker-harden.sh` |
| `command not found` (node/cliclick) | PATH not loaded in SSH | `fleet-ssh` handles this; or `export PATH=/opt/homebrew/bin:$PATH` |
| Playwright fails | Not installed properly | `cd ~/fleet-tools && npm install playwright && npx playwright install chromium` |
| VNC won't connect | Screen Sharing off | System Settings → Sharing → Screen Sharing → ON |
| Worker on different network unreachable | Extreme firewall blocking Tailscale | Try mobile hotspot; watchdog retries every 5 min |

---

## AI Agent Skill (mac-control)

This repo includes an **AI agent skill** in `skills/mac-control/` for automated cross-machine operations. The skill provides a 4-level decision tree:

| Level | Tool | When to use | Token cost |
|-------|------|-------------|------------|
| 1 | `fleet-exec.sh` | CLI commands (95% of tasks) | Zero |
| 2 | `fleet-browse.sh` | Headless browser automation | Zero |
| 3 | `fleet-look.sh` | Screenshot + vision analysis | Medium |
| 4 | `fleet-act.sh` | Mouse/keyboard simulation (last resort) | Low |

**Rule: Always use the lowest level that can solve the task.**

---

## Cross-Account Control (different Tailscale accounts)

By default, all machines use the same Tailscale account. If a worker must use a different account, use **Tailscale Node Sharing**:

1. Worker logs in with their own Tailscale account
2. Master opens https://login.tailscale.com/admin/machines
3. Find the worker device → **"..."** → **Share**
4. Enter the master's Tailscale account email
5. Master accepts the share invitation
6. Networks are now connected — run `worker-setup.sh` as normal

**Note:** If the other party logs out or revokes sharing, you lose access. For 100% reliable control, use a single shared account.

Docs: https://tailscale.com/kb/1084/sharing

---

## Files

| File | Purpose |
|------|---------|
| `master-setup.sh` | Master setup (env check + fleet-ssh + registry) |
| `worker-setup.sh` | Worker setup (tools + SSH keys + auto-register) |
| `worker-harden.sh` | Worker hardening (always-on + self-healing watchdog) |
| `fleet-ssh` | Fleet control tool (list/ping/shell/run) |
| `skills/mac-control/` | AI agent skill for cross-machine ops |
| `SOP.md` | Detailed operations manual (Chinese) |
| `SECURITY.md` | Security disclaimer & legal notice |

---

## Security

- All traffic encrypted via Tailscale WireGuard — no public ports
- SSH uses ED25519 keys — no password brute-force risk
- Tailscale ACLs can restrict which machines can communicate
- `worker-harden.sh` disables screen lock and auto-updates — suitable for managed environments only

**See [SECURITY.md](SECURITY.md) for full disclaimer.**

---

## License

MIT — See [LICENSE](LICENSE)
