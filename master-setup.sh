#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Mac Fleet Control — Master Setup (v2)
#
# Run on any Mac that needs to CONTROL other Macs.
# Usage: bash master-setup.sh
#
# Prerequisites (manual, one-time):
#   1. Install Tailscale (App Store or brew install --cask tailscale)
#   2. Open Tailscale, log in, connect to your network
#
# What this script does:
#   1. Check Tailscale is connected
#   2. Enable macOS Remote Login (SSH)
#   3. Create SSH key (if not present)
#   4. Install fleet-ssh tool
#   5. Initialize machine registry
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

ERRORS=0

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
# Step 1/5: Check Tailscale
# ════════════════════════════════════════
step "Step 1/5: Check Tailscale"

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
# Step 2/5: macOS Remote Login (SSH)
# ════════════════════════════════════════
step "Step 2/5: macOS Remote Login (SSH)"

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
# Step 3/5: SSH Key
# ════════════════════════════════════════
step "Step 3/5: SSH Key"

mkdir -p ~/.ssh && chmod 700 ~/.ssh
if [ -f ~/.ssh/id_ed25519 ]; then
  log "SSH key exists: ~/.ssh/id_ed25519"
else
  ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519 -q
  log "SSH key generated: ~/.ssh/id_ed25519"
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
# Step 4/5: Install fleet-ssh
# ════════════════════════════════════════
step "Step 4/5: Install fleet-ssh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/fleet-ssh" ]; then
  sudo cp "$SCRIPT_DIR/fleet-ssh" /usr/local/bin/fleet-ssh 2>/dev/null || cp "$SCRIPT_DIR/fleet-ssh" /usr/local/bin/fleet-ssh
  sudo chmod +x /usr/local/bin/fleet-ssh 2>/dev/null || chmod +x /usr/local/bin/fleet-ssh
  log "fleet-ssh installed to /usr/local/bin/fleet-ssh"
else
  err "fleet-ssh not found in $SCRIPT_DIR"
  ERRORS=$((ERRORS + 1))
fi

# ════════════════════════════════════════
# Step 5/5: Machine Registry
# ════════════════════════════════════════
step "Step 5/5: Machine Registry"

FLEET_FILE="$HOME/.fleet-machines.json"
if [ -f "$FLEET_FILE" ]; then
  COUNT=$(python3 -c "import json; print(len(json.load(open('$FLEET_FILE')).get('machines',[])))" 2>/dev/null || echo "?")
  log "Registry exists: $COUNT machine(s)"
else
  echo '{"machines":[]}' > "$FLEET_FILE"
  log "Registry created: $FLEET_FILE"
fi

# ════════════════════════════════════════
# Done
# ════════════════════════════════════════
echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo -e "${BOLD}${YELLOW}════════════════════════════════════════${NC}"
  echo -e "${BOLD}${YELLOW}  Master Setup Done (with $ERRORS warning(s))${NC}"
  echo -e "${BOLD}${YELLOW}════════════════════════════════════════${NC}"
else
  echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
  echo -e "${BOLD}${GREEN}  Master Setup Complete ✓${NC}"
  echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
fi
echo ""
echo -e "  Hostname:      ${CYAN}$TS_NAME${NC}"
echo -e "  Tailscale IP:  ${CYAN}$TS_IP${NC}"
echo -e "  Username:      ${CYAN}$(whoami)${NC}"
echo -e "  Registry:      ${CYAN}$FLEET_FILE${NC}"
echo ""
echo -e "  ${BOLD}Next: run worker-setup.sh on each Mac you want to control:${NC}"
echo -e "  ${CYAN}bash worker-setup.sh --master $(whoami)@$TS_IP${NC}"
echo ""
echo -e "  ${BOLD}Commands:${NC}"
echo -e "  ${CYAN}fleet-ssh list${NC}              Show all machines"
echo -e "  ${CYAN}fleet-ssh 1 \"command\"${NC}       Run on machine #1"
echo -e "  ${CYAN}fleet-ssh all \"command\"${NC}     Run on all machines"
echo -e "  ${CYAN}fleet-ssh shell 1${NC}           SSH into machine #1"
echo ""
