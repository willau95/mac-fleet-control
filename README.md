# Mac Fleet Control 🖥️

![GitHub stars](https://img.shields.io/github/stars/willau95/mac-fleet-control)
![GitHub license](https://img.shields.io/github/license/willau95/mac-fleet-control)
![GitHub last commit](https://img.shields.io/github/last-commit/willau95/mac-fleet-control)

> ⚠️ **This software is provided "AS IS" without warranty. You are solely responsible for authorization, compliance, and security. See [SECURITY.md](SECURITY.md) for full disclaimer.**

**[中文文档](README_CN.md)** | English

**One command to fully control any Mac remotely.** Zero-config networking, end-to-end encrypted.

Terminal commands · Browser automation · Mouse & keyboard · Screenshots · VNC remote desktop — all supported.

---

## 📋 Prerequisites (read this first if you have a brand-new Mac)

Before running any of the scripts in this repo, the following must be true on **every** Mac you plan to use (both masters and workers). This whole section is a one-time, ~5 minute setup per machine. After this, everything else is automated.

### What you need

| | Requirement |
|---|---|
| **Hardware** | Any Mac (Intel or Apple Silicon) made in the last ~10 years |
| **OS** | macOS 12 Monterey or newer (older versions may work but aren't tested) |
| **Disk** | ~5 GB free (mostly for Xcode Command Line Tools + Homebrew + Playwright) |
| **Network** | Any internet connection — even mobile hotspots, behind NAT, or different WiFi networks. Tailscale handles NAT traversal automatically. |
| **Account** | A free Tailscale account (sign up at https://tailscale.com — uses your Google/Apple/Microsoft/GitHub login). All Macs in the fleet must share the **same** Tailscale account. |
| **Admin password** | You'll need your macOS login password a few times during setup (for `sudo`, enabling Remote Login, granting permissions). |

### Step A — Open Terminal

If you've never used Terminal: press `⌘ + Space` → type `Terminal` → press Enter.

A black/white window opens — this is where you'll paste commands. Right-click in the window to paste, then press Enter to run.

> **Brand-new Mac note:** The very first time you run a developer command (like `git`), macOS will pop up a dialog asking to install **Xcode Command Line Tools**. You can click Install now to get it out of the way, but you don't have to — `worker-setup.sh` will trigger it for you in the background later.

### Step B — Install Tailscale on every Mac

Tailscale is the secure network layer that connects all your Macs. **Install on each machine** (master + every worker). Pick **one** of the two methods below — the scripts detect both automatically.

#### Option 1 (recommended) — App Store GUI version

Best for long-running fleet machines. Native auto-start, auto-update, and system permission dialogs.

1. Open the App Store → search **Tailscale** → Install
   *(Direct link: https://apps.apple.com/app/tailscale/id1475387142)*

2. Open Tailscale (it appears as a small icon in the menu bar, top-right of your screen)

3. Click the menu bar icon → **Log in** → choose your login provider (Google / Apple / Microsoft / GitHub / email)

4. **Critical:** every Mac must log in to the **same** Tailscale account, otherwise they can't see each other.

5. Verify it's connected: the menu bar icon should not have a slash through it. To double-check, open Terminal and run:
   ```bash
   /Applications/Tailscale.app/Contents/MacOS/Tailscale ip -4
   ```
   You should see an IP starting with `100.x.x.x` (Tailscale assigns these).

#### Option 2 — Homebrew CLI version

Best if you already live in the terminal or don't want a menu-bar app. Requires a bit more setup (manually start the daemon, run `tailscale up` to log in via browser).

1. Install Homebrew first (if not present):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Install Tailscale via Homebrew. Two flavors:
   - **CLI daemon only** (headless machines / servers):
     ```bash
     brew install tailscale
     sudo brew services start tailscale
     ```
   - **Cask with menu bar app** (identical to App Store version):
     ```bash
     brew install --cask tailscale-app
     ```

3. Log in:
   ```bash
   tailscale up
   ```
   This prints an authentication URL — open it in your browser and log in. Use the **same** Tailscale account on every Mac.

4. Verify:
   ```bash
   tailscale ip -4
   ```
   You should see a `100.x.x.x` IP.

> **App Store vs. Homebrew — which should I pick?** The App Store GUI version auto-starts on boot, auto-updates, and handles system permission dialogs natively — ideal for unattended fleet workers. The Homebrew CLI version is lighter and scriptable, but you'll manage the daemon via `brew services` and re-run `tailscale up` after re-auth events. Both work equally well with this project — the scripts detect either install location (`/Applications/Tailscale.app/...` or `/opt/homebrew/bin/tailscale`). Pick whichever fits your workflow.

### Step C — Sign in once at https://login.tailscale.com (recommended)

Visit https://login.tailscale.com/admin/machines after you've logged in on a couple of Macs. You should see them listed there. This is where you can later remove machines, share with others, or check status. Bookmark it.

### What you DON'T need to install manually

The scripts handle all of this for you — listed here so you know what's coming:

- ❌ **Homebrew** — auto-installed by `worker-setup.sh`. Already installed but `brew` says "command not found"? The script auto-fixes the PATH.
- ❌ **Node.js / npm** — auto-installed via Homebrew.
- ❌ **Playwright + browser** — auto-installed (uses `chromium-headless-shell`, ~70 MB).
- ❌ **cliclick** (mouse/keyboard automation) — auto-installed via Homebrew.
- ❌ **Xcode Command Line Tools** — `worker-setup.sh` triggers a non-interactive install in the background at Step 0, so it overlaps with everything else and saves ~10–20 minutes of perceived wait time. If a system dialog appears anyway, just click **Install**.
- ❌ **SSH keys** — auto-generated and exchanged.

---

## 🚀 Quick Start (3 steps, after Prerequisites are done)

### Step 1 — On your FIRST Mac (becomes the **master**)

```bash
git clone https://github.com/willau95/mac-fleet-control.git ~/mac-fleet-control \
  && cd ~/mac-fleet-control \
  && bash master-setup.sh
```

### Step 2 — On the master, print the worker install command

```bash
fleet-ssh master
```

You'll get a complete, paste-ready block like this:

```bash
git clone https://github.com/willau95/mac-fleet-control.git ~/mac-fleet-control \
  && cd ~/mac-fleet-control \
  && bash worker-setup.sh --master seacapital@100.107.142.39
```

### Step 3 — On EVERY Mac you want to control (workers)

Paste the command from Step 2 into the worker's terminal. It will:
- ✅ Auto-install Homebrew (and fix PATH if already installed)
- ✅ Auto-install Node.js + Playwright (chromium-headless-shell, ~70 MB)
- ✅ Trigger Xcode Command Line Tools install in the background (parallel, saves ~15 min)
- ✅ Set up bidirectional SSH key auth — asks master password **once**
- ✅ Auto-register to the master's fleet
- ✅ Verify everything works

**That's it.** Run `fleet-ssh list` on the master and your new worker is online.

> **Optional 4th step — make workers always-on:** `bash worker-harden.sh` (disables sleep, enables auto-login, installs self-healing watchdog). See [Hardening](#step-3-hardening-always-online) below.

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

## Detailed Setup Reference

### Multiple masters

You can register a worker to several masters at once:

```bash
bash worker-setup.sh --master john@100.x.x.x --master jane@100.y.y.y
```

### What worker-setup.sh actually does

| # | Step | Notes |
|---|------|-------|
| 0 | Pre-trigger Xcode CLT install in background | Saves ~10–20 min vs. brew triggering it serially |
| 1 | Verify Tailscale is connected | Aborts with instructions if not |
| 2 | Enable macOS Remote Login (SSH) | Via `systemsetup` |
| 3 | Generate SSH key + config | Sets `IdentitiesOnly` to avoid auth-flood errors |
| 4 | Install Homebrew + auto-fix PATH + install cliclick + Node + Playwright | **Auto-fixes the common "brew installed but not in PATH" trap** |
| 5 | Create fleet-tools (`screenshot-url.js`, `browser-action.js`, `capture-screen.sh`) | In `~/fleet-tools/` |
| 6 | Bidirectional SSH key exchange + register to master(s) | Asks master password **once** |
| 7 | Print the 3 manual permissions you still need to grant (see below) | One-time, survives reboots |

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

# Print the paste-able worker setup command (run on a master)
fleet-ssh master

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

> ⚠️ **Common trap: "I updated but `fleet-ssh` still acts like the old version."**
>
> Some setups have multiple `fleet-ssh` files in PATH (`~/bin/`, `~/.local/bin/`, `/usr/local/bin/`). The shell uses whichever appears first in PATH, which may shadow the one you just updated. Check with:
>
> ```bash
> type -a fleet-ssh
> ```
>
> If you see more than one path, make the others **symlinks** to the canonical copy so future updates flow through automatically:
>
> ```bash
> rm ~/bin/fleet-ssh ~/.local/bin/fleet-ssh 2>/dev/null
> ln -s /usr/local/bin/fleet-ssh ~/bin/fleet-ssh
> ln -s /usr/local/bin/fleet-ssh ~/.local/bin/fleet-ssh
> ```
>
> Then your update workflow becomes one command: `cd ~/mac-fleet-control && git pull && sudo cp fleet-ssh /usr/local/bin/fleet-ssh` — every PATH entry sees the new version.

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
