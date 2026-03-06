#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Mac Fleet Control — Visual Demo (for screenshots & promotion)
# Usage: bash fleet-demo.sh
# ═══════════════════════════════════════════════════════════════

# Colors
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
M='\033[0;35m'
W='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

clear

# ── Logo Banner ──
echo ""
echo -e "${C}    ╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}    ║${NC}                                                           ${C}║${NC}"
echo -e "${C}    ║${NC}   ${W}${BOLD}███╗   ███╗ █████╗  ██████╗${NC}                              ${C}║${NC}"
echo -e "${C}    ║${NC}   ${W}${BOLD}████╗ ████║██╔══██╗██╔════╝${NC}    ${G}Mac Fleet Control${NC}        ${C}║${NC}"
echo -e "${C}    ║${NC}   ${W}${BOLD}██╔████╔██║███████║██║${NC}         ${DIM}One command. Full control.${NC} ${C}║${NC}"
echo -e "${C}    ║${NC}   ${W}${BOLD}██║╚██╔╝██║██╔══██║██║${NC}         ${DIM}Any Mac. Any network.${NC}     ${C}║${NC}"
echo -e "${C}    ║${NC}   ${W}${BOLD}██║ ╚═╝ ██║██║  ██║╚██████╗${NC}                              ${C}║${NC}"
echo -e "${C}    ║${NC}   ${W}${BOLD}╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝${NC}                              ${C}║${NC}"
echo -e "${C}    ║${NC}                                                           ${C}║${NC}"
echo -e "${C}    ╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

sleep 0.3

# ── Tagline ──
echo -e "    ${Y}⚡${NC} ${BOLD}SSH · Browser · Mouse · Keyboard · Screenshots · VNC${NC}"
echo -e "    ${Y}⚡${NC} ${BOLD}Tailscale WireGuard E2EE · Zero-config · Self-healing${NC}"
echo ""

sleep 0.3

# ── Network Topology ──
echo -e "    ${C}───────────────── Network Topology ─────────────────${NC}"
echo ""

# Detect real machines from fleet registry
FLEET_FILE="${FLEET_FILE:-$HOME/.fleet-machines.json}"

if [ -f "$FLEET_FILE" ] && command -v python3 &>/dev/null; then
  # Parse real machines
  MACHINES=$(python3 -c "
import json
with open('$FLEET_FILE') as f: d = json.load(f)
for m in d['machines']:
    print(m['name'] + '|' + m['user'] + '|' + m['ip'])
" 2>/dev/null)
  
  MASTER_NAME=$(hostname | sed 's/\.local$//')
  MASTER_IP=$(/Applications/Tailscale.app/Contents/MacOS/Tailscale ip -4 2>/dev/null || tailscale ip -4 2>/dev/null || echo "100.x.x.x")
  
  # Master box
  echo -e "                      ${G}┌─────────────────────┐${NC}"
  echo -e "                      ${G}│${NC}  ${W}${BOLD}🖥  MASTER${NC}           ${G}│${NC}"
  printf "                      ${G}│${NC}  %-20s${G}│${NC}\n" "$MASTER_NAME"
  printf "                      ${G}│${NC}  ${DIM}%-20s${NC}${G}│${NC}\n" "$MASTER_IP"
  echo -e "                      ${G}└──────────┬──────────┘${NC}"
  echo -e "                                 ${G}│${NC}"
  echo -e "                      ${C}╔══════════╧══════════╗${NC}"
  echo -e "                      ${C}║${NC} ${Y}🔒 Tailscale E2EE${NC}    ${C}║${NC}"
  echo -e "                      ${C}║${NC} ${DIM}WireGuard Encrypted${NC}  ${C}║${NC}"
  echo -e "                      ${C}╚══════════╤══════════╝${NC}"
  echo -e "                                 ${G}│${NC}"
  
  # Count machines for layout
  MACHINE_COUNT=$(echo "$MACHINES" | wc -l | tr -d ' ')
  
  # Draw branch
  if [ "$MACHINE_COUNT" -ge 2 ]; then
    echo -e "                    ${G}┌────────────┴────────────┐${NC}"
    echo -e "                    ${G}│${NC}                          ${G}│${NC}"
  else
    echo -e "                    ${G}│${NC}"
  fi
  
  # Check each machine status and draw
  i=0
  WORKER_LINES=()
  while IFS='|' read -r name user ip; do
    [ -z "$name" ] && continue
    # Quick connectivity check
    if ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no -o LogLevel=ERROR "$user@$ip" "echo ok" </dev/null &>/dev/null 2>&1; then
      STATUS="${G}● ONLINE${NC}"
    else
      STATUS="${R}● OFFLINE${NC}"
    fi
    
    WORKER_LINES+=("$name|$ip|$STATUS")
    i=$((i + 1))
  done <<< "$MACHINES"
  
  # Draw worker boxes side by side
  if [ ${#WORKER_LINES[@]} -ge 2 ]; then
    # Two workers side by side
    IFS='|' read -r n1 ip1 s1 <<< "${WORKER_LINES[0]}"
    IFS='|' read -r n2 ip2 s2 <<< "${WORKER_LINES[1]}"
    
    printf "         ${G}┌──────────────────────┐${NC}    ${G}┌──────────────────────┐${NC}\n"
    printf "         ${G}│${NC}  ${W}${BOLD}🖥  WORKER 1${NC}          ${G}│${NC}    ${G}│${NC}  ${W}${BOLD}🖥  WORKER 2${NC}          ${G}│${NC}\n"
    printf "         ${G}│${NC}  %-20s ${G}│${NC}    ${G}│${NC}  %-20s ${G}│${NC}\n" "$n1" "$n2"
    printf "         ${G}│${NC}  ${DIM}%-20s${NC} ${G}│${NC}    ${G}│${NC}  ${DIM}%-20s${NC} ${G}│${NC}\n" "$ip1" "$ip2"
    echo -e "         ${G}│${NC}  $s1              ${G}│${NC}    ${G}│${NC}  $s2              ${G}│${NC}"
    printf "         ${G}└──────────────────────┘${NC}    ${G}└──────────────────────┘${NC}\n"
    
    # Extra workers
    for ((j=2; j<${#WORKER_LINES[@]}; j++)); do
      IFS='|' read -r nx ipx sx <<< "${WORKER_LINES[$j]}"
      echo ""
      printf "         ${G}┌──────────────────────┐${NC}\n"
      printf "         ${G}│${NC}  ${W}${BOLD}🖥  WORKER $((j+1))${NC}          ${G}│${NC}\n"
      printf "         ${G}│${NC}  %-20s ${G}│${NC}\n" "$nx"
      printf "         ${G}│${NC}  ${DIM}%-20s${NC} ${G}│${NC}\n" "$ipx"
      echo -e "         ${G}│${NC}  $sx              ${G}│${NC}"
      printf "         ${G}└──────────────────────┘${NC}\n"
    done
  elif [ ${#WORKER_LINES[@]} -eq 1 ]; then
    IFS='|' read -r n1 ip1 s1 <<< "${WORKER_LINES[0]}"
    printf "              ${G}┌──────────────────────┐${NC}\n"
    printf "              ${G}│${NC}  ${W}${BOLD}🖥  WORKER 1${NC}          ${G}│${NC}\n"
    printf "              ${G}│${NC}  %-20s ${G}│${NC}\n" "$n1"
    printf "              ${G}│${NC}  ${DIM}%-20s${NC} ${G}│${NC}\n" "$ip1"
    echo -e "              ${G}│${NC}  $s1              ${G}│${NC}"
    printf "              ${G}└──────────────────────┘${NC}\n"
  fi
  
else
  # No fleet file — show demo topology
  echo -e "                      ${G}┌─────────────────────┐${NC}"
  echo -e "                      ${G}│${NC}  ${W}${BOLD}🖥  MASTER${NC}           ${G}│${NC}"
  echo -e "                      ${G}│${NC}  Your Mac            ${G}│${NC}"
  echo -e "                      ${G}└──────────┬──────────┘${NC}"
  echo -e "                                 ${G}│${NC}"
  echo -e "                      ${C}╔══════════╧══════════╗${NC}"
  echo -e "                      ${C}║${NC} ${Y}🔒 Tailscale E2EE${NC}    ${C}║${NC}"
  echo -e "                      ${C}╚══════════╤══════════╝${NC}"
  echo -e "                                 ${G}│${NC}"
  echo -e "                    ${G}┌────────────┴────────────┐${NC}"
  echo -e "                    ${G}│${NC}                          ${G}│${NC}"
  echo -e "         ${G}┌──────────────────────┐${NC}    ${G}┌──────────────────────┐${NC}"
  echo -e "         ${G}│${NC}  ${W}${BOLD}🖥  WORKER 1${NC}          ${G}│${NC}    ${G}│${NC}  ${W}${BOLD}🖥  WORKER 2${NC}          ${G}│${NC}"
  echo -e "         ${G}│${NC}  Office iMac          ${G}│${NC}    ${G}│${NC}  Home Mac mini        ${G}│${NC}"
  echo -e "         ${G}│${NC}  ${G}● ONLINE${NC}              ${G}│${NC}    ${G}│${NC}  ${G}● ONLINE${NC}              ${G}│${NC}"
  echo -e "         ${G}└──────────────────────┘${NC}    ${G}└──────────────────────┘${NC}"
fi

echo ""

# ── Capabilities ──
echo -e "    ${C}───────────────── Capabilities ──────────────────${NC}"
echo ""
echo -e "    ${G}▸${NC} ${BOLD}fleet-ssh 1 \"uptime\"${NC}                  ${DIM}→ Run any command${NC}"
echo -e "    ${G}▸${NC} ${BOLD}fleet-ssh 1 \"cliclick c:500,500\"${NC}      ${DIM}→ Click mouse${NC}"
echo -e "    ${G}▸${NC} ${BOLD}fleet-ssh 1 \"cliclick t:'Hello'\"${NC}      ${DIM}→ Type text${NC}"
echo -e "    ${G}▸${NC} ${BOLD}fleet-ssh all \"softwareupdate -l\"${NC}     ${DIM}→ All machines${NC}"
echo -e "    ${G}▸${NC} ${BOLD}node ~/fleet-tools/browser-action.js${NC}  ${DIM}→ Browser automation${NC}"
echo -e "    ${G}▸${NC} ${BOLD}open vnc://user@100.x.x.x${NC}            ${DIM}→ Remote desktop${NC}"
echo ""
echo -e "    ${C}─────────────────────────────────────────────────${NC}"
echo ""
echo -e "    ${DIM}github.com/celestwong0920/mac-fleet-control${NC}"
echo -e "    ${DIM}MIT License · Free & Open Source${NC}"
echo ""
