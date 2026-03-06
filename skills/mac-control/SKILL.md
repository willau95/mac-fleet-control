---
name: mac-control
description: Cross-machine remote control for Mac fleet. Use when an agent needs to execute commands, install software, manage files, control apps, or perform any operation on ANOTHER Mac in the fleet. Supports CLI commands (primary), browser automation, and GUI simulation (mouse/keyboard as last resort). Use this skill whenever a task involves a remote machine, cross-device operation, or fleet-wide batch action.
---

# Fleet Control — Cross-Machine Remote Operations

## ⛔ IRON RULE: Never raw SSH. Always use fleet-ssh / fleet-exec.

**NEVER do this:**
```bash
ssh hostname "command"           # ❌ hostname may not resolve
ssh user@192.168.x.x "command"  # ❌ LAN IP may not be reachable
ssh user@100.x.x.x "command"    # ❌ wrong user/key = auth failure
```

**ALWAYS do this:**
```bash
bash {baseDir}/scripts/fleet-exec.sh <machine> "command"   # ✅
fleet-ssh <machine> "command"                               # ✅
```

`fleet-ssh` handles everything: Tailscale IP, correct user, correct SSH key, timeout, PATH setup. If you bypass it, you WILL hit auth failures, hostname resolution errors, or connection refused — and waste time debugging what's already solved.

**If SSH fails even via fleet-ssh:**
1. Run `fleet-ssh list` — is the machine online?
2. If offline → report to user. You cannot wake a powered-off machine.
3. If online but SSH fails → run `fleet-ssh ping` for diagnostics.
4. **Never conclude "impossible" until you've tried fleet-ssh.** Never fall back to "please do it manually" without exhausting fleet-ssh first.

## Decision Tree (MUST follow this order)

```
Task on remote machine?
  ├─ 0. ALWAYS use fleet-ssh  → never raw ssh/scp
  ├─ 1. CLI command?          → fleet-exec (fastest, zero overhead)
  ├─ 2. Browser automation?   → fleet-browse (headless, no GUI)
  ├─ 3. Need to SEE screen?   → fleet-look (screenshot + vision)
  └─ 4. Need GUI interaction? → fleet-act (mouse/keyboard, LAST RESORT)
```

**Rule: Never use Level 4 if Level 1-3 can solve it. Never use Level 3 if Level 1-2 can solve it.**

## Core Commands

All scripts are in `{baseDir}/scripts/`. All take `<machine>` as first arg (number or name from `fleet-ssh list`).

### Level 1: CLI Execution (95% of tasks)

```bash
# Run any command on remote machine
bash {baseDir}/scripts/fleet-exec.sh <machine> "<command>"

# Examples
bash {baseDir}/scripts/fleet-exec.sh 1 "brew install wget"
bash {baseDir}/scripts/fleet-exec.sh 1 "launchctl list | grep openclaw"
bash {baseDir}/scripts/fleet-exec.sh 1 "cat /etc/hosts"
bash {baseDir}/scripts/fleet-exec.sh all "uptime"
```

### Level 2: Browser Automation (headless, no GUI needed)

```bash
# Open URL and screenshot
bash {baseDir}/scripts/fleet-browse.sh <machine> screenshot <url> [output.png]

# Open URL and execute actions
bash {baseDir}/scripts/fleet-browse.sh <machine> action '<json>'

# JSON action format:
# {"url":"https://...","actions":[{"type":"click","selector":"#btn"},{"type":"type","selector":"input","text":"hello"}],"screenshot":"/tmp/result.png"}
```

### Level 3: Vision (screenshot + analyze)

```bash
# Take screenshot of remote screen, returns local path
bash {baseDir}/scripts/fleet-look.sh <machine> [output.png]
```

After getting the screenshot path, use the `image` tool to analyze it.
Only use this when you need to understand what's currently on screen.

### Level 4: GUI Simulation (last resort)

```bash
# Mouse/keyboard actions on remote machine
bash {baseDir}/scripts/fleet-act.sh <machine> <action> [args...]

# Actions:
bash {baseDir}/scripts/fleet-act.sh 1 click 500,300        # click at x,y
bash {baseDir}/scripts/fleet-act.sh 1 doubleclick 500,300   # double click
bash {baseDir}/scripts/fleet-act.sh 1 rightclick 500,300    # right click
bash {baseDir}/scripts/fleet-act.sh 1 move 500,300          # move mouse
bash {baseDir}/scripts/fleet-act.sh 1 type "hello world"    # type text
bash {baseDir}/scripts/fleet-act.sh 1 key return            # press key
bash {baseDir}/scripts/fleet-act.sh 1 key command-a         # shortcut
bash {baseDir}/scripts/fleet-act.sh 1 key command-c         # copy
bash {baseDir}/scripts/fleet-act.sh 1 key command-v         # paste
bash {baseDir}/scripts/fleet-act.sh 1 scroll up 5           # scroll
bash {baseDir}/scripts/fleet-act.sh 1 scroll down 5
```

## GUI Control Loop (Level 3+4 combined)

When CLI/browser can't solve it, use this loop:

```
1. fleet-look → screenshot
2. image tool → analyze screenshot, identify target coordinates
3. fleet-act → click/type/key
4. fleet-look → verify result
5. Repeat until done
```

**Token optimization:** Minimize loop iterations. Plan multiple actions from one screenshot before taking another.

## Fleet Management

```bash
# List all machines
fleet-ssh list

# Check all online
fleet-ssh ping

# Batch execute
bash {baseDir}/scripts/fleet-exec.sh all "<command>"

# Add/remove machines
fleet-ssh add <name> <user> <ip>
fleet-ssh remove <name>
```

## Common Patterns

See `{baseDir}/references/patterns.md` for:
- Software installation (brew, npm, pip)
- Service management (launchd, launchctl)
- File transfer (scp between machines)
- App launching and control
- System configuration (defaults, pmset)
- User/permission management
- Network diagnostics

See `{baseDir}/references/gui-patterns.md` for:
- Clicking Allow/Deny dialogs
- Navigating System Settings
- Filling forms in GUI apps
- Handling popups and notifications

## Constraints

- **NEVER raw SSH** — always use `fleet-ssh` or `fleet-exec.sh`. No exceptions.
- **Always check `fleet-ssh list` first** to confirm machine is online
- **CLI first** — if a terminal command exists for the task, use it
- **Batch when possible** — use `fleet-exec.sh all` for fleet-wide ops
- **Minimize screenshots** — each screenshot costs vision tokens
- **One screenshot, multiple actions** — plan ahead from what you see
- **Never say "please do it manually"** — if fleet-ssh can reach the machine, YOU execute it. Only report impossibility if the machine is genuinely offline/unreachable via `fleet-ssh list`.
- **SCP also uses fleet registry** — for file transfer, resolve user@ip from `fleet-ssh list` output, don't guess
