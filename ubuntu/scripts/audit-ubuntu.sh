#!/usr/bin/env bash
# ==============================================================================
# audit-ubuntu.sh — 100% Read-Only Ubuntu / Linux DX × AX Environment Diagnostic
# ==============================================================================
# Part of ax-playbook (Chapter 2: Resilient Agent Dev-Box)
# Checks all 4 pillars of Ubuntu / WSL2 / Cloud VM Agent Experience:
#   1. System, Kernel boot_id, RAM/Swap Pressure & Disk/Inode Watermarks
#   2. Tmux Server Topology & Multi-Runtime Agent JSONL / DB Session Stores
#      (OMP, Google Antigravity agy, Claude Code, OpenAI Codex)
#   3. Docker Storage Hygiene (dangling cache, :candidate vs :stable images)
#      & Git Worktree Sprawl
#   4. Security Guardrails (0.0.0.0 listening sockets, tunnels, cron/systemd
#      checkpoint jobs & stale git locks)
#
# Safety: 100% READ-ONLY. Never modifies files, containers, or processes.
# ==============================================================================

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

section() {
  printf "\n${BOLD}${CYAN}== %s ==${RESET}\n" "$1"
}

ok()   { printf "  ${GREEN}[OK]${RESET}   %s\n" "$1"; }
warn() { printf "  ${YELLOW}[WARN]${RESET} %s\n" "$1"; }
crit() { printf "  ${RED}[CRIT]${RESET} %s\n" "$1"; }
info() { printf "  ${CYAN}[INFO]${RESET} %s\n" "$1"; }

dir_size_human() {
  local target="$1"
  if [ -e "$target" ]; then
    du -sh "$target" 2>/dev/null | awk '{print $1}' || echo "N/A"
  else
    echo "0B (not found)"
  fi
}

printf "${BOLD}Ubuntu / Linux DX × AX Environment Audit (100%% Read-Only)${RESET}\n"
printf "Timestamp: %s\n" "$(date '+%Y-%m-%d %H:%M:%S %z')"

# ------------------------------------------------------------------------------
# 1. System, Boot-ID, Memory/Swap & Disk/Inode Watermarks
# ------------------------------------------------------------------------------
section "1. System, Kernel Boot-ID, Memory & Disk/Inode Health"

OS_NAME="Linux"
if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  OS_NAME="$(. /etc/os-release && echo "${PRETTY_NAME:-Linux}")"
elif [ "$(uname -s)" = "Darwin" ]; then
  OS_NAME="macOS $(sw_vers -productVersion 2>/dev/null || echo unknown) (compatibility mode)"
fi

KERNEL_VER="$(uname -sr)"
ARCH="$(uname -m)"
HOST_SHORT="$(hostname -s 2>/dev/null || hostname)"

if [ -r /proc/sys/kernel/random/boot_id ]; then
  BOOT_ID="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown)"
elif command -v sysctl >/dev/null 2>&1; then
  BOOT_ID="$(sysctl -n kern.bootsessionuuid 2>/dev/null || echo unknown)"
else
  BOOT_ID="unknown"
fi

UPTIME_STR="$(uptime -p 2>/dev/null || uptime | sed 's/^.*up /up /' | cut -d',' -f1-2)"

info "OS: ${OS_NAME} | Kernel: ${KERNEL_VER} (${ARCH})"
info "Host: ${HOST_SHORT} | Boot-ID: ${BOOT_ID} | Uptime: ${UPTIME_STR}"

if grep -qi "microsoft" /proc/version 2>/dev/null; then
  info "Environment: WSL2 detected"
fi

# Memory & Swap check
if command -v free >/dev/null 2>&1; then
  MEM_LINE="$(free -h | awk '/^Mem:/ {printf "Total: %s | Used: %s | Available: %s", $2, $3, $7}')"
  SWAP_LINE="$(free -h | awk '/^Swap:/ {printf "Total: %s | Used: %s", $2, $3}')"
  info "Memory -> ${MEM_LINE}"
  info "Swap   -> ${SWAP_LINE}"
fi

# Disk space watermark check (warn >= 85%, crit >= 92%)
while IFS= read -r df_line; do
  [ -z "$df_line" ] && continue
  FS_PCT="$(echo "$df_line" | awk '{gsub(/%/,"",$5); print $5}')"
  FS_MNT="$(echo "$df_line" | awk '{print $6}')"
  if [[ "$FS_PCT" =~ ^[0-9]+$ ]]; then
    if [ "$FS_PCT" -ge 92 ]; then
      crit "Disk usage CRITICAL (${FS_PCT}%) on ${FS_MNT}: ${df_line} — Agent JSONL/SQLite writes may fail!"
    elif [ "$FS_PCT" -ge 85 ]; then
      warn "Disk usage HIGH (${FS_PCT}%) on ${FS_MNT}: ${df_line}"
    else
      ok "Disk usage healthy (${FS_PCT}%) on ${FS_MNT}: ${df_line}"
    fi
  fi
done < <(df -hP / "$HOME" 2>/dev/null | awk 'NR>1' | sort -u)

# Inode watermark check
if df -iP / >/dev/null 2>&1; then
  INODE_PCT="$(df -iP / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')"
  if [[ "$INODE_PCT" =~ ^[0-9]+$ ]] && [ "$INODE_PCT" -ge 85 ]; then
    warn "Root filesystem inode usage is high (${INODE_PCT}%) — check node_modules or small cache files."
  else
    ok "Root filesystem inode usage healthy (${INODE_PCT:-0}%)."
  fi
fi

# ------------------------------------------------------------------------------
# 2. Pillar 1: Multi-Runtime Tmux Topology & Agent Session Stores
# ------------------------------------------------------------------------------
section "2. Pillar 1 — Tmux Topology & Multi-Agent Session Stores"

if command -v tmux >/dev/null 2>&1; then
  if tmux list-sessions >/dev/null 2>&1; then
    SESS_COUNT="$(tmux list-sessions 2>/dev/null | wc -l | tr -d ' ')"
    WIN_COUNT="$(tmux list-windows -a 2>/dev/null | wc -l | tr -d ' ')"
    PANE_COUNT="$(tmux list-panes -a 2>/dev/null | wc -l | tr -d ' ')"
    ok "Tmux server active: ${SESS_COUNT} session(s), ${WIN_COUNT} window(s), ${PANE_COUNT} pane(s)."

    # Summarize pane commands
    PANE_CMDS="$(tmux list-panes -a -F '#{pane_current_command}' 2>/dev/null | sort | uniq -c | tr '\n' '; ' || true)"
    info "Active pane foreground commands: ${PANE_CMDS}"
  else
    warn "tmux is installed, but no active tmux server/sessions found for UID $(id -u)."
  fi
else
  warn "tmux is not installed."
fi

# Check the 4 Agent Runtime stores
# 2a. OMP (~/.omp/agent/sessions)
OMP_DIR="$HOME/.omp/agent/sessions"
if [ -d "$OMP_DIR" ]; then
  OMP_JSONLS="$(find "$OMP_DIR" -maxdepth 3 -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')"
  ok "OMP session store: ${OMP_DIR} (${OMP_JSONLS} .jsonl files, $(dir_size_human "$OMP_DIR"))"
else
  info "OMP session store not found at ${OMP_DIR}"
fi

# 2b. Google Antigravity (agy) (~/.gemini/antigravity-cli/conversations)
AGY_DIR="$HOME/.gemini/antigravity-cli/conversations"
if [ -d "$AGY_DIR" ]; then
  AGY_DBS="$(find "$AGY_DIR" -maxdepth 1 -name "*.db" 2>/dev/null | wc -l | tr -d ' ')"
  AGY_LOCKS="$(find "$AGY_DIR" -maxdepth 1 -name "*.lock" 2>/dev/null | wc -l | tr -d ' ')"
  ok "Antigravity (agy) store: ${AGY_DIR} (${AGY_DBS} conversations, ${AGY_LOCKS} lock files, $(dir_size_human "$AGY_DIR"))"
else
  info "Antigravity (agy) store not found at ${AGY_DIR}"
fi

# 2c. Claude Code (~/.claude/projects)
CLAUDE_DIR="$HOME/.claude/projects"
if [ -d "$CLAUDE_DIR" ]; then
  CLAUDE_JSONLS="$(find "$CLAUDE_DIR" -maxdepth 3 -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')"
  ok "Claude Code store: ${CLAUDE_DIR} (${CLAUDE_JSONLS} .jsonl files, $(dir_size_human "$CLAUDE_DIR"))"
else
  info "Claude Code store not found at ${CLAUDE_DIR}"
fi

# 2d. OpenAI Codex (~/.codex/sessions)
CODEX_DIR="$HOME/.codex/sessions"
if [ -d "$CODEX_DIR" ]; then
  CODEX_JSONLS="$(find "$CODEX_DIR" -maxdepth 4 -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')"
  ok "OpenAI Codex store: ${CODEX_DIR} (${CODEX_JSONLS} rollout .jsonl files, $(dir_size_human "$CODEX_DIR"))"
else
  info "OpenAI Codex store not found at ${CODEX_DIR}"
fi

# ------------------------------------------------------------------------------
# 3. Pillar 2: Boot-ID Checkpoint & Preboot Protection Status
# ------------------------------------------------------------------------------
section "3. Pillar 2 — Tmux Checkpoint & Preboot Protection"

CKPT_DIRS=(
  "${AX_CHECKPOINT_DIR:-$HOME/.local/state/ax-playbook/tmux-restores}"
  "$HOME/.dotagents/personal/technical/omp-tmux-restores"
)

FOUND_CKPT=0
for cdir in "${CKPT_DIRS[@]}"; do
  if [ -d "$cdir" ]; then
    FOUND_CKPT=1
    PREBOOT_COUNT="$(find "$cdir" -maxdepth 1 -name "preboot-*.sh" 2>/dev/null | wc -l | tr -d ' ')"
    LATEST_SH="$(find "$cdir" -maxdepth 1 -name "*.sh" ! -name "preboot-*" 2>/dev/null | head -n 1 || true)"
    ok "Checkpoint directory found: ${cdir} (preboot archives: ${PREBOOT_COUNT})"
    if [ -n "$LATEST_SH" ]; then
      info "Latest host checkpoint: ${LATEST_SH} (modified: $(date -r "$LATEST_SH" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c '%y' "$LATEST_SH" 2>/dev/null || echo unknown))"
    fi
  fi
done

if [ "$FOUND_CKPT" -eq 0 ]; then
  warn "No tmux checkpoint directory found yet. Run './ubuntu/scripts/tmux-agent-checkpoint.sh' to initialize."
fi

# Check crontab / systemd user timers for periodic checkpoint
CRON_CHECK="$(crontab -l 2>/dev/null | grep -E 'checkpoint|tmux' || true)"
if [ -n "$CRON_CHECK" ]; then
  ok "Crontab checkpoint entry detected: $(echo "$CRON_CHECK" | head -n 1)"
else
  info "No tmux checkpoint entry found in user crontab."
fi

# ------------------------------------------------------------------------------
# 4. Pillar 3: Docker Candidate Image Bloat & Git Worktree Hygiene
# ------------------------------------------------------------------------------
section "4. Pillar 3 — Docker Candidate Hygiene & Git Worktrees"

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    ok "Docker daemon reachable."
    docker system df 2>/dev/null | sed 's/^/    /' || true

    CANDIDATE_COUNT="$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -c ':candidate$' || true)"
    DANGLING_COUNT="$(docker images -f 'dangling=true' -q 2>/dev/null | wc -l | tr -d ' ')"

    if [ "${CANDIDATE_COUNT:-0}" -gt 3 ]; then
      warn "Found ${CANDIDATE_COUNT} ':candidate' Docker images — review and prune obsolete candidates while keeping ':stable'."
    else
      ok "Docker ':candidate' image count is low (${CANDIDATE_COUNT:-0})."
    fi

    if [ "${DANGLING_COUNT:-0}" -gt 5 ]; then
      warn "Found ${DANGLING_COUNT} dangling (<none>) Docker images reclaimable via 'docker image prune'."
    else
      ok "Dangling Docker images: ${DANGLING_COUNT:-0}."
    fi
  else
    info "Docker CLI installed, but daemon is not running or current user lacks socket permission."
  fi
else
  info "Docker not installed on this host."
fi

# Check Git worktree directories and stale index.lock files
for WT_BASE in "$HOME/workspace/.worktrees" "$HOME/.worktrees"; do
  if [ -d "$WT_BASE" ]; then
    WT_COUNT="$(find "$WT_BASE" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    info "Git worktree pool ${WT_BASE}: ${WT_COUNT} worktree(s), total size $(dir_size_human "$WT_BASE")"
  fi
done

STALE_LOCKS="$(find "$HOME/workspace" -maxdepth 4 -name "index.lock" -mmin +10 2>/dev/null | wc -l | tr -d ' ' || true)"
if [ "${STALE_LOCKS:-0}" -gt 0 ]; then
  warn "Found ${STALE_LOCKS} git index.lock file(s) older than 10 minutes under ~/workspace."
else
  ok "No stale git index.lock files (>10m) found under ~/workspace."
fi

# ------------------------------------------------------------------------------
# 5. Pillar 4: External Dashboard / Listening Ports & Tunnel Guardrails
# ------------------------------------------------------------------------------
section "5. Pillar 4 — Network Exposure & Tunnel Security Guardrails"

if command -v ss >/dev/null 2>&1; then
  PUBLIC_PORTS="$(ss -tulpnH 2>/dev/null | awk '$5 ~ /^(0\.0\.0\.0:|\[::\]:|\*:)/ && $5 !~ /:22$/ {print $5, $7}' || true)"
  if [ -n "$PUBLIC_PORTS" ]; then
    warn "Services listening on wildcard 0.0.0.0 / [::] (verify firewall or bind to 127.0.0.1 / Tailscale):"
    echo "$PUBLIC_PORTS" | head -n 10 | sed 's/^/    /'
  else
    ok "No non-SSH application ports listening on wildcard 0.0.0.0 / [::]."
  fi
elif command -v lsof >/dev/null 2>&1; then
  PUBLIC_PORTS="$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk '$9 ~ /^\*:/ && $9 !~ /\*:22$/ {print $1, $2, $9}' | sort -u || true)"
  if [ -n "$PUBLIC_PORTS" ]; then
    warn "Services listening on wildcard *:<port> (verify firewall or bind to 127.0.0.1):"
    echo "$PUBLIC_PORTS" | head -n 10 | sed 's/^/    /'
  else
    ok "No non-SSH services listening on wildcard *:<port>."
  fi
fi

# Check active tunnel processes (cloudflared / ngrok / tailscaled)
for TUN_BIN in cloudflared ngrok tailscaled; do
  if pgrep -x "$TUN_BIN" >/dev/null 2>&1; then
    info "Active tunnel/mesh daemon detected: ${TUN_BIN} (ensure public web routes enforce HTTP 401 Passcode / Zero-Trust gate)."
  fi
done

printf "\n${BOLD}${GREEN}Audit complete (0 files modified).${RESET} See ubuntu/README.md & AGENTS.md for tuning steps.\n"
