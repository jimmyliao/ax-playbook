#!/usr/bin/env bash
# ==============================================================================
# audit-macos.sh — 100% Read-Only macOS DX × AX Environment Diagnostic
# ==============================================================================
# Part of ax-playbook (Chapter 1: Lean Agent Mac)
# Checks all 5 pillars of macOS 26/27 (Tahoe) Developer & Agent Experience:
#   1. System, Hardware, RAM Pressure & APFS Free Space
#   2. Chrome 136+ CDP Isolation, Profile Size & Port 9222 Readiness
#   3. APFS `code_sign_clone` Bloat, Old Chrome Frameworks & Post-Upgrade Storage
#   4. System UI (Menu Bar Spacing), Spotlight Indexing & Terminal Fonts
#   5. AI Agent Runtime (Tmux, LaunchAgent Guards) & Apple `fm` CLI Readiness
#
# Safety: 100% READ-ONLY. Does not modify files, defaults, or running processes.
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
info() { printf "  ${CYAN}[INFO]${RESET} %s\n" "$1"; }

dir_size_human() {
  local target="$1"
  if [ -e "$target" ]; then
    du -sh "$target" 2>/dev/null | awk '{print $1}' || echo "N/A"
  else
    echo "0B (not found)"
  fi
}

printf "${BOLD}macOS DX × AX Environment Audit (100%% Read-Only)${RESET}\n"
printf "Timestamp: %s\n" "$(date '+%Y-%m-%d %H:%M:%S %z')"

# ------------------------------------------------------------------------------
# 1. System, Hardware, RAM & APFS Storage
# ------------------------------------------------------------------------------
section "1. System, Memory & APFS Volume Health"

OS_VER="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
OS_BUILD="$(sw_vers -buildVersion 2>/dev/null || echo unknown)"
ARCH="$(uname -m)"
LOCAL_HOST="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
SHORT_HOST="$(hostname -s 2>/dev/null || echo unknown)"
CHIP="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)"
RAM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
RAM_GB=$(( RAM_BYTES / 1024 / 1024 / 1024 ))
BOOT_UUID="$(sysctl -n kern.bootsessionuuid 2>/dev/null || echo unknown)"

info "macOS: ${OS_VER} (Build ${OS_BUILD}) | Chip: ${CHIP} (${ARCH}) | RAM: ${RAM_GB} GB"
info "LocalHostName: ${LOCAL_HOST} | hostname -s: ${SHORT_HOST} | BootUUID: ${BOOT_UUID}"

if [ "$LOCAL_HOST" != "$SHORT_HOST" ]; then
  warn "DHCP hostname ('${SHORT_HOST}') differs from LocalHostName ('${LOCAL_HOST}'). Scripts should use 'scutil --get LocalHostName'."
else
  ok "LocalHostName matches hostname -s ('${LOCAL_HOST}')."
fi

SWAP_INFO="$(sysctl -n vm.swapusage 2>/dev/null || echo 'N/A')"
info "Swap Usage: ${SWAP_INFO}"

DF_LINE="$(df -h /System/Volumes/Data 2>/dev/null | tail -n 1 || df -h / | tail -n 1)"
info "APFS Data Volume: ${DF_LINE}"

# ------------------------------------------------------------------------------
# 2. Pillar 1: Chrome 136+ CDP Dual-Instance Isolation & Startup Readiness
# ------------------------------------------------------------------------------
section "2. Pillar 1 — Chrome 136+ CDP Isolation & Fast Launcher"

for APP_NAME in "Google Chrome Dev.app" "Google Chrome.app" "Chrome Dev (CDP Agent).app"; do
  APP_PATH="/Applications/${APP_NAME}"
  if [ -d "$APP_PATH" ]; then
    VER="$(defaults read "${APP_PATH}/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo unknown)"
    BUNDLE_ID="$(defaults read "${APP_PATH}/Contents/Info" CFBundleIdentifier 2>/dev/null || echo unknown)"
    APP_SIZE="$(dir_size_human "$APP_PATH")"
    ok "Found ${APP_NAME} (v${VER}, BundleID: ${BUNDLE_ID}, Size: ${APP_SIZE})"
  fi
done

if [ ! -d "/Applications/Chrome Dev (CDP Agent).app" ] && [ ! -d "/Applications/Chrome (CDP Agent).app" ]; then
  warn "No dedicated 'Chrome (CDP Agent).app' wrapper found in /Applications (run './macos/scripts/tune-chrome-cdp.sh install-wrapper' to isolate Dock icons)."
fi

for BIN_NAME in chrome-dev-fast cda; do
  if command -v "$BIN_NAME" >/dev/null 2>&1 || [ -x "$HOME/.local/bin/$BIN_NAME" ]; then
    ok "Fast launcher '${BIN_NAME}' installed ($HOME/.local/bin/${BIN_NAME})"
  else
    info "Fast launcher '${BIN_NAME}' not found in ~/.local/bin (can use ./macos/scripts/tune-chrome-cdp.sh launch)"
  fi
done

if lsof -nP -iTCP:9222 -sTCP:LISTEN >/dev/null 2>&1; then
  CDP_PID="$(lsof -tiTCP:9222 -sTCP:LISTEN | head -n 1)"
  ok "CDP Port 9222 is ACTIVE (PID: ${CDP_PID}) — warm attach (~450ms) ready."
else
  info "CDP Port 9222 is not currently listening."
fi

# Check Keystone background updater plists
for KS_PLIST in "$HOME/Library/LaunchAgents/com.google.keystone.agent.plist" "$HOME/Library/LaunchAgents/com.google.keystone.xpcservice.plist"; do
  if [ -f "$KS_PLIST" ]; then
    KS_SIZE="$(wc -c < "$KS_PLIST" | tr -d ' ')"
    if [ "$KS_SIZE" -le 220 ]; then
      ok "Keystone LaunchAgent neutered (${KS_PLIST##*/}, ${KS_SIZE} bytes)"
    else
      warn "Keystone LaunchAgent active (${KS_PLIST##*/}, ${KS_SIZE} bytes) — may cause background CPU spikes."
    fi
  fi
done

# ------------------------------------------------------------------------------
# 3. Pillar 2: APFS `code_sign_clone` Bloat & Chrome Cache / Framework Hygiene
# ------------------------------------------------------------------------------
section "3. Pillar 2 — APFS code_sign_clone & Storage Hygiene"

CLONE_DIRS=()
while IFS= read -r line; do
  [ -n "$line" ] && CLONE_DIRS+=("$line")
done < <(find /private/var/folders -maxdepth 4 -name "*.code_sign_clone" 2>/dev/null || true)

if [ "${#CLONE_DIRS[@]}" -gt 0 ]; then
  for cdir in "${CLONE_DIRS[@]}"; do
    CSIZE="$(dir_size_human "$cdir")"
    COUNT="$(find "$cdir" -maxdepth 1 -name "code_sign_clone.*" 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$COUNT" -gt 0 ]; then
      warn "APFS Gatekeeper orphan clones in ${cdir}: ${COUNT} bundle(s), logical size ${CSIZE}"
    else
      ok "No orphan bundles inside ${cdir} (${CSIZE})"
    fi
  done
else
  ok "No /private/var/folders/*/*.code_sign_clone directories found."
fi

# Check Chrome Framework duplicate versions
for CHROME_APP in "/Applications/Google Chrome Dev.app" "/Applications/Google Chrome.app"; do
  VERS_DIR="${CHROME_APP}/Contents/Frameworks/Google Chrome Framework.framework/Versions"
  if [ -d "$VERS_DIR" ]; then
    VER_COUNT="$(find "$VERS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$VER_COUNT" -gt 1 ]; then
      warn "${CHROME_APP##*/} has ${VER_COUNT} Framework Versions inside Versions/ (~750MB reclaimable)."
    else
      ok "${CHROME_APP##*/} has only 1 active Framework Version."
    fi
  fi
done

# Check Chrome Dev & Chrome Caches
for PROF_BASE in "$HOME/Library/Application Support/Google/Chrome Dev" "$HOME/Library/Application Support/Google/Chrome"; do
  if [ -d "$PROF_BASE" ]; then
    BASE_SIZE="$(dir_size_human "$PROF_BASE")"
    info "${PROF_BASE##*/} User Data total: ${BASE_SIZE}"
  fi
done

for CACHE_DIR in "$HOME/Library/Caches/Google/Chrome Dev" "$HOME/Library/Caches/Google/Chrome" "$HOME/.cache/huggingface/hub" "/System/Volumes/Data/macOS Install Data"; do
  if [ -d "$CACHE_DIR" ]; then
    info "Storage check — ${CACHE_DIR}: $(dir_size_human "$CACHE_DIR")"
  fi
done

# ------------------------------------------------------------------------------
# 4. Pillar 3: System UI, Spotlight Apps-Only, Menu Bar & Typography
# ------------------------------------------------------------------------------
section "4. Pillar 3 — System UI, Spotlight, Menu Bar & Typography"

MB_SPACING="$(defaults -currentHost read -globalDomain NSStatusItemSpacing 2>/dev/null || echo default)"
MB_PADDING="$(defaults -currentHost read -globalDomain NSStatusItemSelectionPadding 2>/dev/null || echo default)"
if [ "$MB_SPACING" != "default" ]; then
  ok "Menu Bar compact spacing configured: NSStatusItemSpacing=${MB_SPACING}, NSStatusItemSelectionPadding=${MB_PADDING}"
else
  warn "Menu Bar spacing is at macOS default (can clip icons on 13\"/14\" screens; recommend 6 / 4)."
fi

for HUD_APP in "/Applications/Stats.app" "/Applications/LeapEdge.app"; do
  if [ -d "$HUD_APP" ]; then
    ok "Menu Bar HUD installed: ${HUD_APP}"
  fi
done

# Check .metadata_never_index in common dev/cache dirs
NEVER_INDEX_COUNT=0
for DEV_DIR in "$HOME/workspace" "$HOME/.cache" "$HOME/.npm" "$HOME/.nvm" "$HOME/.cargo" "$HOME/.gradle"; do
  if [ -f "${DEV_DIR}/.metadata_never_index" ]; then
    NEVER_INDEX_COUNT=$(( NEVER_INDEX_COUNT + 1 ))
  fi
done
if [ "$NEVER_INDEX_COUNT" -ge 3 ]; then
  ok "Spotlight .metadata_never_index markers present in ${NEVER_INDEX_COUNT} dev/cache directories."
else
  warn "Only ${NEVER_INDEX_COUNT} dev/cache directories have .metadata_never_index (mds_stores may index node_modules/caches)."
fi

# Check Maple Mono NF CN & Ghostty config
if ls "$HOME/Library/Fonts" /Library/Fonts 2>/dev/null | grep -qi "Maple"; then
  ok "Maple Mono font family detected in system/user Fonts."
else
  info "Maple Mono NF CN font not detected (recommended for CJK + TUI box-drawing alignment)."
fi

GHOSTTY_CFG="$HOME/.config/ghostty/config"
if [ -f "$GHOSTTY_CFG" ]; then
  FONT_CFG="$(grep -E '^font-(family|thicken)' "$GHOSTTY_CFG" 2>/dev/null | tr '\n' '; ' || true)"
  ok "Ghostty config found: ${FONT_CFG:-custom}"
fi

# ------------------------------------------------------------------------------
# 5. Pillar 4 & 5: AI Agent Runtime, Tmux Resilience & Apple `fm` CLI
# ------------------------------------------------------------------------------
section "5. Pillar 4 & 5 — Agent Resilience (Tmux/LaunchAgents) & Apple fm CLI"

if command -v tmux >/dev/null 2>&1; then
  TMUX_COUNT="$(tmux list-sessions 2>/dev/null | wc -l | tr -d ' ' || echo 0)"
  ok "tmux installed (${TMUX_COUNT} active session(s))."
else
  warn "tmux not found in PATH."
fi

# Check agent resilience LaunchAgents (supports any com.*.omp-tmux-checkpoint / cmux-rss-guard / ram-watch)
for LA_SUFFIX in "omp-tmux-checkpoint" "session-restore" "cmux-rss-guard" "ram-watch"; do
  LA_MATCH="$(find "$HOME/Library/LaunchAgents" -maxdepth 1 -name "*${LA_SUFFIX}*.plist" 2>/dev/null | head -n 1 || true)"
  if [ -n "$LA_MATCH" ]; then
    ok "LaunchAgent present: $(basename "$LA_MATCH")"
  else
    info "Optional LaunchAgent not installed: *${LA_SUFFIX}*.plist"
  fi
done

if [ -x "/usr/bin/fm" ]; then
  FM_OUT="$(/usr/bin/fm models 2>&1 || true)"
  FM_RC=$?
  if echo "$FM_OUT" | grep -q "system"; then
    ok "macOS 27 /usr/bin/fm CLI ready: $(echo "$FM_OUT" | tr '\n' ' ')"
  elif [ "$FM_RC" -eq 69 ]; then
    warn "/usr/bin/fm exited with 69 (EX_UNAVAILABLE) — run 'sudo fm license' interactively to accept terms."
  else
    warn "/usr/bin/fm status: ${FM_OUT}"
  fi
else
  info "/usr/bin/fm not present (requires macOS 26/27+ with Apple Foundation Models)."
fi

printf "\n${BOLD}${GREEN}Audit complete (0 files modified).${RESET} See README.md & AGENTS.md for tuning steps.\n"
