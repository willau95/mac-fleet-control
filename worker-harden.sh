#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Mac Fleet Control — Worker Hardening (永远在线)
#
# Run on any worker Mac to ensure 100% remote controllability.
# Usage: bash worker-harden.sh
#
# What it does:
#   1. Disable sleep/hibernation (always awake)
#   2. Tailscale auto-start on boot
#   3. Auto-login current user (no login screen after reboot)
#   4. Disable automatic macOS updates/restarts
#   5. Disable screen lock (no password on wake)
#   6. Keep SSH alive across reboots (verify)
#   7. Create self-healing watchdog (auto-fix if anything breaks)
#
# Safe to run multiple times — idempotent.
# Requires sudo (will prompt once).
# ═══════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
step() { echo -e "\n${CYAN}═══ $1 ═══${NC}"; }

ERRORS=0
WHOAMI=$(whoami)

echo ""
echo -e "${BOLD}Mac Fleet Control — Worker Hardening${NC}"
echo -e "${DIM}Making this Mac permanently remotely controllable${NC}"
echo ""

# Prompt for sudo upfront
sudo -v || { err "Need sudo access"; exit 1; }

# Keep sudo alive during script
while true; do sudo -n true; sleep 30; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEP_PID=$!
trap "kill $SUDO_KEEP_PID 2>/dev/null" EXIT

# ════════════════════════════════════════
# Step 1/7: Disable Sleep & Hibernation
# ════════════════════════════════════════
step "Step 1/7: Disable Sleep & Hibernation"

# Disable system sleep
sudo pmset -a sleep 0 2>/dev/null
sudo pmset -a disksleep 0 2>/dev/null
sudo pmset -a displaysleep 0 2>/dev/null
sudo pmset -a hibernatemode 0 2>/dev/null

# Prevent idle sleep
sudo pmset -a standby 0 2>/dev/null
sudo pmset -a autopoweroff 0 2>/dev/null

# Wake on network access (Wake on LAN)
sudo pmset -a womp 1 2>/dev/null

# Power nap off (prevents weird wake/sleep cycles)
sudo pmset -a powernap 0 2>/dev/null

# Restart on power failure
sudo pmset -a autorestart 1 2>/dev/null

# Restart on freeze
sudo systemsetup -setrestartfreeze on 2>/dev/null

log "Sleep disabled, Wake on LAN enabled, auto-restart on power failure"

# Verify
SLEEP_VAL=$(pmset -g | grep "^ sleep" | awk '{print $2}' 2>/dev/null || echo "?")
if [ "$SLEEP_VAL" = "0" ]; then
  log "Verified: sleep = 0"
else
  warn "Sleep value: $SLEEP_VAL (expected 0)"
fi

# ════════════════════════════════════════
# Step 2/7: Tailscale Auto-Start
# ════════════════════════════════════════
step "Step 2/7: Tailscale Auto-Start on Boot"

# Check which Tailscale is installed
if [ -d "/Applications/Tailscale.app" ]; then
  # App Store version — uses Login Items
  # Check if already in login items
  if osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | grep -qi tailscale; then
    log "Tailscale already in Login Items"
  else
    osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Tailscale.app", hidden:true}' 2>/dev/null
    if [ $? -eq 0 ]; then
      log "Tailscale added to Login Items (auto-start on login)"
    else
      warn "Could not add to Login Items automatically"
      echo -e "  ${DIM}Manual: System Settings → General → Login Items → add Tailscale${NC}"
      ERRORS=$((ERRORS + 1))
    fi
  fi
elif brew list tailscale &>/dev/null 2>&1; then
  # Brew version — use brew services
  if brew services list 2>/dev/null | grep tailscale | grep -q started; then
    log "Tailscale brew service already running"
  else
    brew services start tailscale 2>/dev/null
    log "Tailscale brew service started (auto-start on boot)"
  fi
else
  warn "Tailscale not found — install it first"
  ERRORS=$((ERRORS + 1))
fi

# Verify Tailscale is connected
TS_IP=""
for p in tailscale /opt/homebrew/bin/tailscale "/Applications/Tailscale.app/Contents/MacOS/Tailscale"; do
  if command -v "$p" &>/dev/null || [ -x "$p" ]; then
    TS_IP=$("$p" ip -4 2>/dev/null || echo "")
    [ -n "$TS_IP" ] && break
  fi
done

if [ -n "$TS_IP" ]; then
  log "Tailscale connected: $TS_IP"
else
  err "Tailscale not connected — open the app and connect"
  ERRORS=$((ERRORS + 1))
fi

# ════════════════════════════════════════
# Step 3/7: Auto-Login
# ════════════════════════════════════════
step "Step 3/7: Auto-Login Current User"

echo -e "  ${YELLOW}⚠ Auto-login requires your macOS password.${NC}"
echo -e "  ${DIM}This ensures the Mac logs in automatically after reboot,${NC}"
echo -e "  ${DIM}so SSH and all tools remain accessible.${NC}"
echo ""

# Check if already set
CURRENT_AUTO=$(sudo defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || echo "")
if [ "$CURRENT_AUTO" = "$WHOAMI" ]; then
  log "Auto-login already set for $WHOAMI"
else
  read -sp "  Enter macOS password for $WHOAMI (or press Enter to skip): " MACOS_PASS
  echo ""
  
  if [ -n "$MACOS_PASS" ]; then
    # Set auto-login user
    sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser "$WHOAMI"
    
    # Use kcpassword to store the password
    # This is the standard macOS auto-login mechanism
    python3 << PYEOF
import subprocess, struct, os

password = "$MACOS_PASS"
# XOR key used by macOS kcpassword
key = [125, 137, 82, 35, 210, 188, 221, 234, 163, 185, 31]
encoded = bytearray()
for i, c in enumerate(password.encode('utf-8')):
    encoded.append(c ^ key[i % len(key)])
# Pad to 12-byte boundary
padding = 12 - (len(encoded) % 12)
if padding < 12:
    encoded.extend([0] * padding)

with open('/tmp/kcpassword', 'wb') as f:
    f.write(bytes(encoded))

os.system('sudo cp /tmp/kcpassword /etc/kcpassword')
os.system('sudo chmod 600 /etc/kcpassword')
os.system('sudo chown root:wheel /etc/kcpassword')
os.system('rm /tmp/kcpassword')
print('OK')
PYEOF
    
    if [ -f /etc/kcpassword ]; then
      log "Auto-login configured for $WHOAMI"
    else
      err "Auto-login setup failed"
      ERRORS=$((ERRORS + 1))
    fi
  else
    warn "Skipped auto-login (press Enter was pressed)"
    echo -e "  ${DIM}Manual: System Settings → Users & Groups → Auto Login → select user${NC}"
    ERRORS=$((ERRORS + 1))
  fi
fi

# ════════════════════════════════════════
# Step 4/7: Disable Auto-Updates
# ════════════════════════════════════════
step "Step 4/7: Disable Automatic Updates & Restarts"

# Disable automatic macOS updates
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false 2>/dev/null
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false 2>/dev/null
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool false 2>/dev/null
sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool false 2>/dev/null

# Disable automatic App Store updates
defaults write com.apple.commerce AutoUpdate -bool false 2>/dev/null

# Disable automatic restart for updates
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -bool false 2>/dev/null

log "Automatic updates disabled"
log "Automatic restarts disabled"
echo -e "  ${DIM}You can still manually update when ready: softwareupdate -l${NC}"

# ════════════════════════════════════════
# Step 5/7: Disable Screen Lock
# ════════════════════════════════════════
step "Step 5/7: Disable Screen Lock & Screen Saver Password"

# No password on wake
defaults write com.apple.screensaver askForPassword -int 0 2>/dev/null
defaults write com.apple.screensaver askForPasswordDelay -int 0 2>/dev/null

# Disable screen saver
defaults write com.apple.screensaver idleTime -int 0 2>/dev/null

log "Screen lock disabled (no password on wake)"
log "Screen saver disabled"

# ════════════════════════════════════════
# Step 6/7: Verify SSH
# ════════════════════════════════════════
step "Step 6/7: Verify SSH Persistence"

SSH_STATUS=$(sudo systemsetup -getremotelogin 2>/dev/null || echo "")
if echo "$SSH_STATUS" | grep -qi "on"; then
  log "Remote Login (SSH) is ON — persists across reboots"
else
  sudo systemsetup -f -setremotelogin on 2>/dev/null
  if [ $? -eq 0 ]; then
    log "Remote Login enabled"
  else
    err "Could not enable Remote Login"
    ERRORS=$((ERRORS + 1))
  fi
fi

# ════════════════════════════════════════
# Step 7/7: Self-Healing Watchdog
# ════════════════════════════════════════
step "Step 7/7: Self-Healing Watchdog"

# Create watchdog script
mkdir -p ~/fleet-tools
cat > ~/fleet-tools/fleet-watchdog.sh << 'WATCHEOF'
#!/bin/bash
# Fleet Watchdog — runs every 5 minutes, auto-fixes issues
# Installed by worker-harden.sh

LOG="$HOME/fleet-tools/watchdog.log"
echo "$(date): watchdog check" >> "$LOG"

# Keep log small (last 200 lines)
tail -200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG" 2>/dev/null

# 1. Check Tailscale connected
TS_CLI=""
for p in tailscale /opt/homebrew/bin/tailscale "/Applications/Tailscale.app/Contents/MacOS/Tailscale"; do
  if command -v "$p" &>/dev/null || [ -x "$p" ]; then
    TS_CLI="$p"
    break
  fi
done

if [ -n "$TS_CLI" ]; then
  TS_STATUS=$("$TS_CLI" status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('BackendState',''))" 2>/dev/null || echo "")
  if [ "$TS_STATUS" != "Running" ]; then
    echo "$(date): Tailscale not running (state=$TS_STATUS), attempting fix..." >> "$LOG"
    
    # Try App Store version first
    if [ -d "/Applications/Tailscale.app" ]; then
      open -a Tailscale 2>/dev/null || true
      sleep 5
      echo "$(date): Opened Tailscale.app" >> "$LOG"
    fi
    
    # Try brew service restart (for CLI version)
    if command -v brew &>/dev/null && brew list tailscale &>/dev/null 2>&1; then
      brew services restart tailscale 2>/dev/null || true
      sleep 3
      echo "$(date): Restarted brew tailscale service" >> "$LOG"
    fi
    
    # Try bringing it up
    "$TS_CLI" up 2>/dev/null || true
    echo "$(date): Tailscale restart attempted" >> "$LOG"
  fi
fi

# 2. Check SSH is on
SSH_ON=$(sudo systemsetup -getremotelogin 2>/dev/null | grep -ci "on" || echo "0")
if [ "$SSH_ON" -eq 0 ]; then
  echo "$(date): SSH was OFF, re-enabling..." >> "$LOG"
  sudo systemsetup -f -setremotelogin on 2>/dev/null || true
fi

# 3. Prevent sleep from being re-enabled
SLEEP_VAL=$(pmset -g 2>/dev/null | grep "^ sleep" | awk '{print $2}' || echo "0")
if [ "$SLEEP_VAL" != "0" ]; then
  echo "$(date): Sleep was re-enabled ($SLEEP_VAL), disabling..." >> "$LOG"
  sudo pmset -a sleep 0 2>/dev/null
fi

echo "$(date): watchdog OK" >> "$LOG"
WATCHEOF
chmod +x ~/fleet-tools/fleet-watchdog.sh

# Create launchd plist for watchdog (runs every 5 minutes)
PLIST_PATH="$HOME/Library/LaunchAgents/com.fleet.watchdog.plist"
mkdir -p ~/Library/LaunchAgents

cat > "$PLIST_PATH" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.fleet.watchdog</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${HOME}/fleet-tools/fleet-watchdog.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/fleet-tools/watchdog-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/fleet-tools/watchdog-stderr.log</string>
</dict>
</plist>
PLISTEOF

# Load watchdog
launchctl unload "$PLIST_PATH" 2>/dev/null
launchctl load "$PLIST_PATH" 2>/dev/null

if launchctl list 2>/dev/null | grep -q "com.fleet.watchdog"; then
  log "Watchdog installed (checks every 5 minutes)"
  log "Auto-fixes: Tailscale disconnects, SSH disabled, sleep re-enabled"
else
  err "Watchdog installation failed"
  ERRORS=$((ERRORS + 1))
fi

# ════════════════════════════════════════
# Summary & Verification
# ════════════════════════════════════════
step "Verification"

echo ""
echo -e "  ${BOLD}Checking all hardening settings...${NC}"
echo ""

# Sleep
SLEEP_CHECK=$(pmset -g | grep "^ sleep" | awk '{print $2}' 2>/dev/null || echo "?")
[ "$SLEEP_CHECK" = "0" ] && echo -e "  ${GREEN}✓${NC} Sleep disabled" || echo -e "  ${RED}✗${NC} Sleep: $SLEEP_CHECK (expected 0)"

# Wake on LAN
WOMP_CHECK=$(pmset -g | grep "^ womp" | awk '{print $2}' 2>/dev/null || echo "?")
[ "$WOMP_CHECK" = "1" ] && echo -e "  ${GREEN}✓${NC} Wake on LAN enabled" || echo -e "  ${RED}✗${NC} Wake on LAN: $WOMP_CHECK (expected 1)"

# Auto-restart
AUTORESTART=$(pmset -g | grep "^ autorestart" | awk '{print $2}' 2>/dev/null || echo "?")
[ "$AUTORESTART" = "1" ] && echo -e "  ${GREEN}✓${NC} Auto-restart on power failure" || echo -e "  ${RED}✗${NC} Auto-restart: $AUTORESTART (expected 1)"

# Tailscale
[ -n "$TS_IP" ] && echo -e "  ${GREEN}✓${NC} Tailscale connected: $TS_IP" || echo -e "  ${RED}✗${NC} Tailscale not connected"

# Auto-login
AUTO_USER=$(sudo defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || echo "")
[ "$AUTO_USER" = "$WHOAMI" ] && echo -e "  ${GREEN}✓${NC} Auto-login: $WHOAMI" || echo -e "  ${YELLOW}!${NC} Auto-login not set"

# Auto-updates
AUTO_UPDATE=$(sudo defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload 2>/dev/null || echo "1")
[ "$AUTO_UPDATE" = "0" ] && echo -e "  ${GREEN}✓${NC} Auto-updates disabled" || echo -e "  ${YELLOW}!${NC} Auto-updates may be on"

# Screen lock
SCREEN_LOCK=$(defaults read com.apple.screensaver askForPassword 2>/dev/null || echo "1")
[ "$SCREEN_LOCK" = "0" ] && echo -e "  ${GREEN}✓${NC} Screen lock disabled" || echo -e "  ${YELLOW}!${NC} Screen lock may be on"

# SSH
SSH_CHECK=$(sudo systemsetup -getremotelogin 2>/dev/null || echo "")
echo "$SSH_CHECK" | grep -qi "on" && echo -e "  ${GREEN}✓${NC} SSH enabled" || echo -e "  ${RED}✗${NC} SSH not enabled"

# Watchdog
launchctl list 2>/dev/null | grep -q "com.fleet.watchdog" && echo -e "  ${GREEN}✓${NC} Watchdog running" || echo -e "  ${RED}✗${NC} Watchdog not running"

echo ""

# ════════════════════════════════════════
# Done
# ════════════════════════════════════════
if [ "$ERRORS" -gt 0 ]; then
  echo -e "${BOLD}${YELLOW}════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${YELLOW}  Hardening Done (with $ERRORS warning(s) — see above)${NC}"
  echo -e "${BOLD}${YELLOW}════════════════════════════════════════════════════${NC}"
else
  echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${GREEN}  Worker Hardening Complete ✓${NC}"
  echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════${NC}"
fi
echo ""
echo -e "  ${BOLD}This machine is now:${NC}"
echo -e "  • Never sleeps"
echo -e "  • Auto-starts Tailscale on boot"
echo -e "  • Auto-logs in after reboot"
echo -e "  • Won't auto-update/restart"
echo -e "  • No screen lock"
echo -e "  • SSH always on"
echo -e "  • Self-healing watchdog (every 5 min)"
echo ""
echo -e "  ${DIM}Watchdog log: ~/fleet-tools/watchdog.log${NC}"
echo -e "  ${DIM}Safe to run again — all settings are idempotent.${NC}"
echo ""
