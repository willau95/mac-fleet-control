#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Mac Fleet Control — Worker Setup (v2)
#
# Run on any Mac that needs to BE CONTROLLED by masters.
# Usage: bash worker-setup.sh --master user@ip
#
# Prerequisites (manual, one-time):
#   1. Install Tailscale (App Store or brew install --cask tailscale)
#   2. Open Tailscale, log in, connect to your network
#
# What this script does:
#   1. Check Tailscale is connected
#   2. Enable macOS Remote Login (SSH)
#   3. Install tools (cliclick, Playwright)
#   4. Create fleet helper scripts
#   5. Setup SSH key auth to master (password once)
#   6. Auto-register to master's fleet
#   7. Show manual permissions guide
#
# Safe to run multiple times — won't break anything.
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

MASTERS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --master) MASTERS+=("$2"); shift 2 ;;
    *) shift ;;
  esac
done

[ ${#MASTERS[@]} -eq 0 ] && {
  echo -e "${RED}[✗]${NC} Usage: bash worker-setup.sh --master user@ip"
  echo -e "    Example: bash worker-setup.sh --master john@100.x.x.x"
  echo -e "    Multiple: bash worker-setup.sh --master user1@ip1 --master user2@ip2"
  exit 1
}

ERRORS=0
WHOAMI=$(whoami)

# ── Detect Tailscale CLI ──
detect_tailscale() {
  for p in tailscale /opt/homebrew/bin/tailscale /usr/local/bin/tailscale "/Applications/Tailscale.app/Contents/MacOS/Tailscale"; do
    if command -v "$p" &>/dev/null || [ -x "$p" ]; then
      if "$p" version &>/dev/null 2>&1; then
        echo "$p"
        return 0
      fi
    fi
  done
  return 1
}

# ════════════════════════════════════════
# Step 1/7: Check Tailscale
# ════════════════════════════════════════
step "Step 1/7: Check Tailscale"

TS_CLI=$(detect_tailscale)
if [ -z "$TS_CLI" ]; then
  err "Tailscale not found."
  echo ""
  echo -e "  ${BOLD}Install Tailscale from the App Store:${NC}"
  echo -e "    ${CYAN}https://apps.apple.com/app/tailscale/id1475387142${NC}"
  echo ""
  echo -e "  Then open Tailscale, log in, and re-run this script."
  exit 1
fi

TS_IP=$("$TS_CLI" ip -4 2>/dev/null || echo "")
if [ -z "$TS_IP" ]; then
  err "Tailscale installed but not connected."
  echo ""
  echo -e "  Open Tailscale app and connect to your network first."
  exit 1
fi

TS_NAME=$("$TS_CLI" status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('Self',{}).get('HostName',''))" 2>/dev/null || hostname -s)
log "Tailscale connected: $TS_NAME ($TS_IP)"

# ════════════════════════════════════════
# Step 2/7: macOS Remote Login (SSH)
# ════════════════════════════════════════
step "Step 2/7: macOS Remote Login (SSH)"

SSH_STATUS=$(sudo systemsetup -getremotelogin 2>/dev/null || echo "")
if echo "$SSH_STATUS" | grep -qi "on"; then
  log "Remote Login already enabled"
else
  if sudo systemsetup -f -setremotelogin on 2>/dev/null; then
    log "Remote Login enabled"
  elif sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist 2>/dev/null; then
    log "Remote Login enabled (via launchctl)"
  else
    err "Could not enable Remote Login automatically."
    echo -e "  Enable manually: ${CYAN}System Settings → General → Sharing → Remote Login → ON${NC}"
    ERRORS=$((ERRORS + 1))
  fi
fi

# ════════════════════════════════════════
# Step 3/7: SSH Key
# ════════════════════════════════════════
step "Step 3/7: SSH Key"

mkdir -p ~/.ssh && chmod 700 ~/.ssh
if [ -f ~/.ssh/id_ed25519 ]; then
  log "SSH key exists"
else
  ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519 -q
  log "SSH key generated"
fi

# Prevent "too many authentication failures"
if ! grep -q "IdentitiesOnly" ~/.ssh/config 2>/dev/null; then
  echo -e "\nHost *\n  IdentitiesOnly yes\n  IdentityFile ~/.ssh/id_ed25519" >> ~/.ssh/config
  chmod 600 ~/.ssh/config
  log "SSH config: IdentitiesOnly enabled"
else
  log "SSH config already set"
fi

# ════════════════════════════════════════
# Step 4/7: Install Tools
# ════════════════════════════════════════
step "Step 4/7: Install Tools"

# ── Ensure Homebrew is installed AND in PATH ──
# Common new-Mac trap: brew installer prints PATH-config commands but doesn't run
# them, so a fresh shell still gets `command not found: brew`. We auto-fix it.
ensure_brew_path() {
  local brew_bin=""
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$p" ] && { brew_bin="$p"; break; }
  done
  [ -z "$brew_bin" ] && return 1

  # Persist to ~/.zprofile if not already there (idempotent)
  if ! grep -q "brew shellenv" "$HOME/.zprofile" 2>/dev/null; then
    [ -s "$HOME/.zprofile" ] && echo "" >> "$HOME/.zprofile"
    echo "eval \"\$($brew_bin shellenv)\"" >> "$HOME/.zprofile"
    log "Added Homebrew to ~/.zprofile"
  fi

  # Also write to ~/.zshrc for non-login shells (some setups bypass .zprofile)
  if ! grep -q "brew shellenv" "$HOME/.zshrc" 2>/dev/null; then
    [ -s "$HOME/.zshrc" ] && echo "" >> "$HOME/.zshrc"
    echo "eval \"\$($brew_bin shellenv)\"" >> "$HOME/.zshrc"
  fi

  # Activate in current session
  eval "$("$brew_bin" shellenv)"
  return 0
}

if ! command -v brew &>/dev/null; then
  # Case A: brew binary exists but PATH not configured (the usual new-Mac bug)
  if ensure_brew_path; then
    log "Homebrew found at $(command -v brew) — PATH auto-configured"
  else
    # Case B: brew genuinely not installed — install non-interactively
    warn "Homebrew not installed. Installing now (non-interactive)..."
    if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
      if ensure_brew_path; then
        log "Homebrew installed and PATH configured"
      else
        err "Homebrew installed but PATH config failed — open a new terminal and re-run"
        ERRORS=$((ERRORS + 1))
      fi
    else
      err "Homebrew install failed. Install manually: https://brew.sh"
      ERRORS=$((ERRORS + 1))
    fi
  fi
fi

if ! command -v brew &>/dev/null; then
  err "Homebrew still not available — skipping tool installation"
  ERRORS=$((ERRORS + 1))
else
  # cliclick
  if command -v cliclick &>/dev/null; then
    log "cliclick already installed"
  else
    warn "Installing cliclick..."
    if brew install cliclick 2>/dev/null; then
      log "cliclick installed"
    else
      err "cliclick install failed — mouse control won't work"
      ERRORS=$((ERRORS + 1))
    fi
  fi
fi

# Node.js check (auto-install via brew)
if ! command -v node &>/dev/null; then
  warn "Node.js not found. Installing via brew..."
  if brew install node 2>&1 | tail -3; then
    log "Node.js installed: $(node -v 2>/dev/null || echo 'pending PATH refresh')"
  else
    err "Node.js install failed — Playwright won't work"
    ERRORS=$((ERRORS + 1))
  fi
fi

if ! command -v node &>/dev/null; then
  err "Node.js still not available — skipping Playwright"
  ERRORS=$((ERRORS + 1))
else
  # Playwright
  if [ -d "$HOME/fleet-tools/node_modules/playwright" ]; then
    log "Playwright already installed"
  else
    warn "Installing Playwright + Chromium..."
    mkdir -p ~/fleet-tools
    cd ~/fleet-tools
    npm init -y &>/dev/null
    if npm install playwright &>/dev/null; then
      npx playwright install chromium 2>&1 | tail -1
      log "Playwright + Chromium installed"
    else
      err "Playwright install failed — browser automation won't work"
      ERRORS=$((ERRORS + 1))
    fi
    cd - &>/dev/null
  fi
fi

# ════════════════════════════════════════
# Step 5/7: Fleet Helper Scripts
# ════════════════════════════════════════
step "Step 5/7: Fleet Helper Scripts"

mkdir -p ~/fleet-tools

# Screenshot URL tool
cat > ~/fleet-tools/screenshot-url.js << 'JSEOF'
// Usage: node screenshot-url.js <url> <output.png>
const { chromium } = require('playwright');
(async () => {
  const url = process.argv[2] || 'https://example.com';
  const output = process.argv[3] || '/tmp/fleet-screenshot.png';
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 }).catch(() => {});
  await page.screenshot({ path: output, fullPage: false });
  console.log(`Screenshot saved: ${output}`);
  await browser.close();
})();
JSEOF

# Browser action tool
cat > ~/fleet-tools/browser-action.js << 'JSEOF'
// Usage: node browser-action.js '<json>'
// Example: node browser-action.js '{"url":"https://google.com","actions":[{"type":"click","selector":"input"}]}'
const { chromium } = require('playwright');
(async () => {
  const input = JSON.parse(process.argv[2] || '{}');
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  if (input.url) await page.goto(input.url, { waitUntil: 'networkidle', timeout: 30000 }).catch(() => {});
  for (const act of (input.actions || [])) {
    try {
      if (act.type === 'click') await page.click(act.selector, { timeout: 5000 });
      else if (act.type === 'type') await page.fill(act.selector, act.text);
      else if (act.type === 'wait') await page.waitForTimeout(act.ms || 1000);
      else if (act.type === 'screenshot') await page.screenshot({ path: act.path || '/tmp/fleet-action.png' });
      console.log(`OK: ${act.type} ${act.selector || ''}`);
    } catch (e) { console.log(`FAIL: ${act.type} — ${e.message}`); }
  }
  if (input.screenshot) await page.screenshot({ path: input.screenshot });
  console.log(`Page: ${await page.title()}`);
  await browser.close();
})();
JSEOF

# Screen capture tool
cat > ~/fleet-tools/capture-screen.sh << 'SHEOF'
#!/bin/bash
OUTPUT="${1:-/tmp/fleet-screen.png}"
screencapture -x "$OUTPUT" 2>/dev/null
if [ -f "$OUTPUT" ]; then
  echo "Screenshot saved: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
else
  echo "Screen capture failed (need Screen Recording permission)"
  echo "Grant: System Settings → Privacy & Security → Screen Recording"
fi
SHEOF
chmod +x ~/fleet-tools/capture-screen.sh

log "Fleet helper scripts created in ~/fleet-tools/"

# ════════════════════════════════════════
# Step 6/7: Register to Master(s)
# ════════════════════════════════════════
step "Step 6/7: Register to Master(s)"

SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o LogLevel=ERROR"

for MASTER in "${MASTERS[@]}"; do
  echo ""
  echo -e "  ${BOLD}Registering to ${CYAN}$MASTER${NC}..."

  # Step A: Setup SSH key auth (asks master password ONCE)
  echo -e "  ${DIM}Setting up SSH key auth (may ask master's password once)...${NC}"
  ssh-copy-id $SSH_OPTS "$MASTER" 2>/dev/null
  
  # Verify SSH works
  if ! ssh $SSH_OPTS "$MASTER" "echo ok" &>/dev/null; then
    err "Cannot SSH to $MASTER — check password/connectivity"
    echo -e "  ${DIM}Manual fallback on master: fleet-ssh add \"$TS_NAME\" \"$WHOAMI\" \"$TS_IP\"${NC}"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Step B: Copy SSH key FROM master to this worker (so master can SSH here without password)
  echo -e "  ${DIM}Getting master's SSH key...${NC}"
  MASTER_KEY=$(ssh $SSH_OPTS "$MASTER" "cat ~/.ssh/id_ed25519.pub 2>/dev/null || cat ~/.ssh/id_rsa.pub 2>/dev/null" 2>/dev/null || echo "")
  
  if [ -n "$MASTER_KEY" ]; then
    # Add master's key to our authorized_keys (idempotent)
    mkdir -p ~/.ssh
    touch ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    if ! grep -q "$MASTER_KEY" ~/.ssh/authorized_keys 2>/dev/null; then
      echo "$MASTER_KEY" >> ~/.ssh/authorized_keys
      log "Master's SSH key added to authorized_keys"
    else
      log "Master's SSH key already authorized"
    fi
  else
    warn "Could not get master's SSH key"
    echo -e "  ${DIM}Run on master: ssh-copy-id $WHOAMI@$TS_IP${NC}"
    ERRORS=$((ERRORS + 1))
  fi

  # Step C: Register this machine to master's fleet
  REGISTER_CMD="
FLEET_FILE=\$HOME/.fleet-machines.json
[ ! -f \"\$FLEET_FILE\" ] && echo '{\"machines\":[]}' > \"\$FLEET_FILE\"
python3 << 'PYEOF'
import json, datetime, os
fpath = os.path.expanduser('~/.fleet-machines.json')
try:
    with open(fpath) as fh:
        d = json.load(fh)
except:
    d = {'machines': []}
machines = d.get('machines', [])
# Remove existing entry for same name or IP (update)
machines = [m for m in machines if m.get('ip') != '$TS_IP']
machines.append({
    'name': '$TS_NAME',
    'user': '$WHOAMI',
    'ip': '$TS_IP',
    'added': datetime.datetime.now().isoformat()
})
d['machines'] = machines
with open(fpath, 'w') as fh:
    json.dump(d, fh, indent=2)
print('Registered: $TS_NAME ($WHOAMI@$TS_IP)')
PYEOF
"
  
  if ssh $SSH_OPTS "$MASTER" "$REGISTER_CMD" 2>/dev/null; then
    log "Registered to $MASTER"
  else
    err "Could not register to $MASTER"
    echo -e "  ${DIM}Manual fallback on master: fleet-ssh add \"$TS_NAME\" \"$WHOAMI\" \"$TS_IP\"${NC}"
    ERRORS=$((ERRORS + 1))
  fi
  
  # Step D: Verify master can SSH back to us
  echo -e "  ${DIM}Verifying master can connect back...${NC}"
  VERIFY=$(ssh $SSH_OPTS "$MASTER" "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o LogLevel=ERROR $WHOAMI@$TS_IP 'echo ok'" 2>/dev/null || echo "")
  if [ "$VERIFY" = "ok" ]; then
    log "Verified: master can control this machine ✓"
  else
    warn "Master cannot SSH back yet"
    echo -e "  ${DIM}On master, run: ssh-copy-id $WHOAMI@$TS_IP${NC}"
    ERRORS=$((ERRORS + 1))
  fi
done

# ════════════════════════════════════════
# Step 7/7: Manual Permissions Guide
# ════════════════════════════════════════
step "Step 7/7: Manual Permissions (one-time)"

# Pick the correct Tailscale target based on how it was installed.
# GUI install (App Store / official .pkg) → grant the Tailscale.app bundle.
# Homebrew CLI install → grant the tailscaled binary.
case "$TS_CLI" in
  /Applications/Tailscale.app/*)
    TS_PERM_TARGET="/Applications/Tailscale.app"
    TS_PERM_HOWTO="In the file picker, navigate to ${BOLD}/Applications${NC}, select ${BOLD}Tailscale.app${NC} (the whole app — do NOT go inside it)."
    ;;
  /opt/homebrew/*|/usr/local/*)
    TS_PERM_TARGET="$(dirname "$TS_CLI")/tailscaled"
    [ ! -e "$TS_PERM_TARGET" ] && TS_PERM_TARGET="$TS_CLI"
    TS_PERM_HOWTO="Press ${BOLD}Cmd+Shift+G${NC} and paste: ${CYAN}$TS_PERM_TARGET${NC}"
    ;;
  *)
    TS_PERM_TARGET="/Applications/Tailscale.app"
    TS_PERM_HOWTO="In the file picker, select ${BOLD}/Applications/Tailscale.app${NC}."
    ;;
esac

echo ""
echo -e "  ${BOLD}${YELLOW}⚠ Set these ONCE in System Settings — they survive reboots:${NC}"
echo -e "  ${DIM}(Detected Tailscale install: $TS_CLI)${NC}"
echo ""
echo -e "  ${BOLD}1. Screen Sharing${NC} (for VNC remote desktop)"
echo -e "     System Settings → General → Sharing → ${CYAN}Screen Sharing → ON${NC}"
echo ""
echo -e "  ${BOLD}2. Screen Recording${NC} (for remote screenshots)"
echo -e "     System Settings → Privacy & Security → ${CYAN}Screen & System Audio Recording${NC}"
echo -e "     → Click ${BOLD}+${NC} → add these two entries:"
echo -e "       a) ${CYAN}/usr/libexec/sshd-keygen-wrapper${NC} ${DIM}(Cmd+Shift+G to paste)${NC}"
echo -e "       b) ${CYAN}$TS_PERM_TARGET${NC}"
echo -e "          ${DIM}$TS_PERM_HOWTO${NC}"
echo ""
echo -e "  ${BOLD}3. Accessibility${NC} (for remote mouse/keyboard)"
echo -e "     System Settings → Privacy & Security → ${CYAN}Accessibility${NC}"
echo -e "     → Click ${BOLD}+${NC} → add these two entries:"
echo -e "       a) ${CYAN}/usr/libexec/sshd-keygen-wrapper${NC} ${DIM}(Cmd+Shift+G to paste)${NC}"
echo -e "       b) ${CYAN}$TS_PERM_TARGET${NC}"
echo ""

# ════════════════════════════════════════
# Self-test
# ════════════════════════════════════════
step "Self-Test"

echo -e "  Checking tools..."
for tool in cliclick node npm; do
  if command -v $tool &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $tool"
  else
    echo -e "  ${RED}✗${NC} $tool — not found"
  fi
done

if [ -d ~/fleet-tools/node_modules/playwright ]; then
  echo -e "  ${GREEN}✓${NC} playwright"
else
  echo -e "  ${RED}✗${NC} playwright — not installed"
fi

echo -e "  ${GREEN}✓${NC} fleet-tools scripts"

SSH_CHECK=$(sudo systemsetup -getremotelogin 2>/dev/null || echo "")
if echo "$SSH_CHECK" | grep -qi "on"; then
  echo -e "  ${GREEN}✓${NC} Remote Login (SSH)"
else
  echo -e "  ${RED}✗${NC} Remote Login (SSH) — enable in System Settings"
fi

echo ""

# ════════════════════════════════════════
# Done
# ════════════════════════════════════════
if [ "$ERRORS" -gt 0 ]; then
  echo -e "${BOLD}${YELLOW}════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${YELLOW}  Worker Setup Done (with $ERRORS warning(s) — see above)${NC}"
  echo -e "${BOLD}${YELLOW}════════════════════════════════════════════════════${NC}"
else
  echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${GREEN}  Worker Setup Complete ✓${NC}"
  echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════${NC}"
fi
echo ""
echo -e "  Hostname:      ${CYAN}$TS_NAME${NC}"
echo -e "  Tailscale IP:  ${CYAN}$TS_IP${NC}"
echo -e "  Username:      ${CYAN}$WHOAMI${NC}"
echo ""
MASTER_DISPLAY="${MASTERS[0]}"
echo ""
echo -e "  ${CYAN}┌─────────────────────┐${NC}          ${CYAN}┌─────────────────────┐${NC}"
echo -e "  ${CYAN}│${NC} ${BOLD}🖥  MASTER${NC}           ${CYAN}│${NC}          ${CYAN}│${NC} ${BOLD}🖥  THIS MAC${NC}          ${CYAN}│${NC}"
printf "  ${CYAN}│${NC} %-20s${CYAN}│${NC}" "$MASTER_DISPLAY"
printf "          ${CYAN}│${NC} %-20s${CYAN}│${NC}\n" "$TS_NAME"
printf "  ${CYAN}│${NC} ${DIM}%-20s${NC}${CYAN}│${NC}" " "
printf "          ${CYAN}│${NC} ${DIM}%-20s${NC}${CYAN}│${NC}\n" "$TS_IP"
echo -e "  ${CYAN}└──────────┬──────────┘${NC}          ${CYAN}└──────────┬──────────┘${NC}"
echo -e "             ${CYAN}│${NC}                                ${CYAN}│${NC}"
echo -e "             ${CYAN}└──────── ${GREEN}🔒 Tailscale E2EE${NC} ${CYAN}────────┘${NC}"
echo ""
echo -e "  ${BOLD}Masters can now:${NC}"
echo -e "  ${CYAN}fleet-ssh list${NC}"
echo -e "  ${CYAN}fleet-ssh \"$TS_NAME\" \"any command\"${NC}"
echo -e "  ${CYAN}fleet-ssh \"$TS_NAME\" \"cliclick m:500,500\"${NC}"
echo ""
echo -e "  ${DIM}Don't forget to set the 3 permissions above (Step 7) if you haven't already!${NC}"
echo -e "  ${DIM}github.com/celestwong0920/mac-fleet-control${NC}"
echo ""
