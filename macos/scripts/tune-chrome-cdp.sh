#!/usr/bin/env bash
# ==============================================================================
# tune-chrome-cdp.sh — Chrome 136+ CDP Dual-Instance Launcher & Hygiene Tool
# ==============================================================================
# Solves Chrome 136+ --remote-debugging-port restrictions & bloated profile lag:
#   - `audit`           : Read-only check of Chrome versions, caches & code_sign_clone
#   - `launch`          : Launch fast isolated Chrome with CDP on port 9222 (~459ms attach)
#   - `clean --dry-run` : Preview reclaimable code_sign_clone, old Frameworks & safe caches
#   - `clean --apply`   : Safely clean transient caches & orphan clones (preserves Bookmarks/Cookies/Logins)
#   - `install-wrapper` : Create standalone '/Applications/Chrome Dev (CDP Agent).app'
# ==============================================================================

set -euo pipefail

CDP_PORT="${CDP_PORT:-9222}"
PROFILE_DIR="${CDP_PROFILE_DIR:-$HOME/.cache/chrome-dev-fast}"
WRAPPER_APP="/Applications/Chrome Dev (CDP Agent).app"

# Locate Chrome Dev first, fallback to Google Chrome
if [ -x "/Applications/Google Chrome Dev.app/Contents/MacOS/Google Chrome Dev" ]; then
  CHROME_APP="/Applications/Google Chrome Dev.app"
  CHROME_BIN="${CHROME_APP}/Contents/MacOS/Google Chrome Dev"
  CHROME_CACHE_DIR="$HOME/Library/Caches/Google/Chrome Dev"
  CHROME_USER_DATA_DIR="$HOME/Library/Application Support/Google/Chrome Dev"
elif [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
  CHROME_APP="/Applications/Google Chrome.app"
  CHROME_BIN="${CHROME_APP}/Contents/MacOS/Google Chrome"
  CHROME_CACHE_DIR="$HOME/Library/Caches/Google/Chrome"
  CHROME_USER_DATA_DIR="$HOME/Library/Application Support/Google/Chrome"
else
  CHROME_APP=""
  CHROME_BIN=""
  CHROME_CACHE_DIR=""
  CHROME_USER_DATA_DIR=""
fi

usage() {
  cat << 'EOF'
Usage: ./macos/scripts/tune-chrome-cdp.sh <command> [options]

Commands:
  audit                 Read-only inspection of Chrome CDP port, profile sizes,
                        old Framework versions, and APFS code_sign_clone bloat.
  launch [options]      Launch or attach to an isolated fast Chrome CDP instance.
    --port=PORT         CDP debugging port (default: 9222)
    --tmp               Use an ephemeral /tmp profile (auto-cleaned on exit)
    --headless          Run in headless mode (--headless=new --disable-gpu)
    --reset             Wipe the isolated CDP profile before launching
  clean [options]       Clean orphan code_sign_clone bundles, old Framework versions,
                        and safe transient caches (NEVER touches Bookmarks/Logins/Cookies).
    --dry-run           Preview what would be cleaned and sizes (default)
    --apply             Perform the cleanup
  install-wrapper       Create standalone '/Applications/Chrome Dev (CDP Agent).app'
                        so Dock & Cmd+Tab distinguish CDP Agent from daily Chrome.
  help                  Show this help message.
EOF
}

ensure_chrome() {
  if [ -z "$CHROME_BIN" ] || [ ! -x "$CHROME_BIN" ]; then
    echo "Error: Neither Google Chrome Dev.app nor Google Chrome.app found in /Applications." >&2
    exit 1
  fi
}

size_of() {
  local p="$1"
  if [ -e "$p" ]; then
    du -sh "$p" 2>/dev/null | awk '{print $1}' || echo "0B"
  else
    echo "0B"
  fi
}

cmd_audit() {
  ensure_chrome
  echo "=== Chrome CDP & Storage Hygiene Audit (Read-Only) ==="
  echo "Detected Browser : ${CHROME_APP} ($(size_of "$CHROME_APP"))"
  echo "Daily User Data  : ${CHROME_USER_DATA_DIR} ($(size_of "$CHROME_USER_DATA_DIR"))"
  echo "Isolated CDP Dir : ${PROFILE_DIR} ($(size_of "$PROFILE_DIR"))"

  if lsof -nP -iTCP:"${CDP_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "CDP Port ${CDP_PORT}    : LISTENING (PID $(lsof -tiTCP:"${CDP_PORT}" -sTCP:LISTEN | head -n 1))"
  else
    echo "CDP Port ${CDP_PORT}    : NOT LISTENING"
  fi

  echo ""
  echo "--- 1. APFS Gatekeeper code_sign_clone Orphans ---"
  find /private/var/folders -maxdepth 4 -name "*.code_sign_clone" 2>/dev/null | while IFS= read -r cdir; do
    echo "  ${cdir} -> $(size_of "$cdir")"
  done

  echo ""
  echo "--- 2. Chrome Framework Versions ---"
  local vdir="${CHROME_APP}/Contents/Frameworks/Google Chrome Framework.framework/Versions"
  if [ -d "$vdir" ]; then
    local current_ver
    current_ver="$(readlink "${vdir}/Current" 2>/dev/null || echo unknown)"
    echo "  Active Current -> ${current_ver}"
    for d in "$vdir"/*; do
      [ -e "$d" ] || continue
      [ "$(basename "$d")" = "Current" ] && continue
      echo "  Version $(basename "$d"): $(size_of "$d")"
    done
  fi

  echo ""
  echo "--- 3. Safe Transient Caches (Bookmarks/Cookies/Logins Excluded) ---"
  echo "  Browser System Cache (${CHROME_CACHE_DIR}): $(size_of "$CHROME_CACHE_DIR")"
  if [ -d "$CHROME_USER_DATA_DIR" ]; then
    for sub in "component_crx_cache" "ShaderCache" "GrShaderCache" "GraphiteDawnCache" "optimization_guide_model_store"; do
      [ -e "${CHROME_USER_DATA_DIR}/${sub}" ] && echo "  UserData/${sub}: $(size_of "${CHROME_USER_DATA_DIR}/${sub}")"
    done
    for prof in "$CHROME_USER_DATA_DIR"/Default "$CHROME_USER_DATA_DIR"/Profile*; do
      [ -d "$prof" ] || continue
      for pcache in "Service Worker/CacheStorage" "Service Worker/ScriptCache" "GPUCache" "DawnGraphiteCache" "DawnWebGPUCache" "Code Cache"; do
        if [ -d "${prof}/${pcache}" ]; then
          echo "  $(basename "$prof")/${pcache}: $(size_of "${prof}/${pcache}")"
        fi
      done
    done
  fi
}

cmd_launch() {
  ensure_chrome
  local use_tmp=0
  local headless=0
  local reset=0
  local extra_args=()

  for arg in "$@"; do
    case "$arg" in
      --tmp) use_tmp=1 ;;
      --headless) headless=1 ;;
      --reset) reset=1 ;;
      --port=*) CDP_PORT="${arg#*=}" ;;
      *) extra_args+=("$arg") ;;
    esac
  done

  # If already listening on CDP_PORT, report ready immediately
  if lsof -nP -iTCP:"${CDP_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
    local pid
    pid="$(lsof -tiTCP:"${CDP_PORT}" -sTCP:LISTEN | head -n 1)"
    echo "Chrome CDP is already running on port ${CDP_PORT} (PID: ${pid})."
    curl -s "http://127.0.0.1:${CDP_PORT}/json/version" | head -n 6 || true
    return 0
  fi

  if [ "$use_tmp" -eq 1 ]; then
    PROFILE_DIR="$(mktemp -d /tmp/chrome-cdp-fast.XXXXXX)"
  else
    [ "$reset" -eq 1 ] && rm -rf "$PROFILE_DIR"
    mkdir -p "$PROFILE_DIR"
  fi

  # Clear stale singleton locks if no process owns the port
  rm -f "${PROFILE_DIR}/SingletonLock" "${PROFILE_DIR}/SingletonCookie" "${PROFILE_DIR}/SingletonSocket"

  local flags=(
    "--user-data-dir=${PROFILE_DIR}"
    "--remote-debugging-port=${CDP_PORT}"
    "--no-first-run"
    "--no-default-browser-check"
    "--disable-background-networking"
    "--disable-background-timer-throttling"
    "--disable-backgrounding-occluded-windows"
    "--disable-Component-update"
    "--disable-component-update"
    "--disable-sync"
    "--disable-default-apps"
    "--metrics-recording-only"
    "--disable-domain-reliability"
    "--disable-breakpad"
    "--disable-client-side-phishing-detection"
    "--disable-hang-monitor"
    "--disable-popup-blocking"
    "--disable-prompt-on-repost"
    "--disable-renderer-backgrounding"
    "--disable-features=Translate,OptimizationHints,MediaRouter,DialMediaRouteProvider,CalculateNativeWinOcclusion,OptimizationGuideModelDownloading,OptimizationHintsFetching,OptimizationTargetPrediction,OptimizationGuideOnDeviceModel,OnDeviceModelService"
    "--password-store=basic"
    "--use-mock-keychain"
    "--window-name=🟢 [CDP Agent] Chrome"
  )

  if [ "$headless" -eq 1 ]; then
    # --disable-gpu avoids macOS CVDisplayLinkCreateWithCGDisplay failed (-6670) in headless mode
    flags+=("--headless=new" "--disable-gpu")
  fi

  echo "Launching isolated Chrome CDP on port ${CDP_PORT} (Profile: ${PROFILE_DIR})..."
  "$CHROME_BIN" "${flags[@]}" "${extra_args[@]+"${extra_args[@]}"}" "about:blank" >/dev/null 2>&1 &
  local chrome_pid=$!

  local tries=0
  while [ "$tries" -lt 50 ]; do
    if lsof -nP -iTCP:"${CDP_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
      echo "Ready! Chrome CDP listening on http://127.0.0.1:${CDP_PORT} (PID: ${chrome_pid})"
      return 0
    fi
    sleep 0.1
    tries=$(( tries + 1 ))
  done

  echo "Warning: Chrome launched (PID: ${chrome_pid}) but port ${CDP_PORT} did not respond within 5s." >&2
  return 1
}

cmd_clean() {
  ensure_chrome
  local apply=0
  for arg in "$@"; do
    case "$arg" in
      --apply) apply=1 ;;
      --dry-run) apply=0 ;;
    esac
  done

  if [ "$apply" -eq 0 ]; then
    echo "[DRY-RUN] Previewing safe cleanup targets (pass --apply to execute):"
  else
    echo "[APPLY] Cleaning transient caches and orphan clones (Bookmarks/Cookies/Logins preserved):"
  fi

  clean_target() {
    local target="$1"
    if [ -e "$target" ]; then
      local sz
      sz="$(size_of "$target")"
      if [ "$apply" -eq 1 ]; then
        rm -rf "$target" 2>/dev/null || true
        echo "  [CLEANED] ${target} (${sz})"
      else
        echo "  [WOULD CLEAN] ${target} (${sz})"
      fi
    fi
  }

  # 1. APFS code_sign_clone orphan bundles
  while IFS= read -r clone_bundle; do
    [ -n "$clone_bundle" ] && clean_target "$clone_bundle"
  done < <(find /private/var/folders -maxdepth 5 -path "*/*.code_sign_clone/code_sign_clone.*" 2>/dev/null || true)

  # 2. Outdated Chrome Framework versions (keep Current)
  local vdir="${CHROME_APP}/Contents/Frameworks/Google Chrome Framework.framework/Versions"
  if [ -d "$vdir" ]; then
    local cur
    cur="$(readlink "${vdir}/Current" 2>/dev/null || echo "")"
    if [ -n "$cur" ]; then
      for d in "$vdir"/*; do
        [ -d "$d" ] || continue
        local bname
        bname="$(basename "$d")"
        if [ "$bname" != "Current" ] && [ "$bname" != "$cur" ]; then
          clean_target "$d"
        fi
      done
    fi
  fi

  # 3. Safe transient caches
  clean_target "$CHROME_CACHE_DIR"
  if [ -d "$CHROME_USER_DATA_DIR" ]; then
    for sub in "component_crx_cache" "ShaderCache" "GrShaderCache" "GraphiteDawnCache" "optimization_guide_model_store" "Local Traces"; do
      clean_target "${CHROME_USER_DATA_DIR}/${sub}"
    done
    for prof in "$CHROME_USER_DATA_DIR"/Default "$CHROME_USER_DATA_DIR"/Profile*; do
      [ -d "$prof" ] || continue
      for pcache in "Service Worker/CacheStorage" "Service Worker/ScriptCache" "GPUCache" "DawnGraphiteCache" "DawnWebGPUCache" "Code Cache"; do
        clean_target "${prof}/${pcache}"
      done
    done
  fi
}

cmd_install_wrapper() {
  ensure_chrome
  local macos_dir="${WRAPPER_APP}/Contents/MacOS"
  local res_dir="${WRAPPER_APP}/Contents/Resources"
  mkdir -p "$macos_dir" "$res_dir"

  cat > "${WRAPPER_APP}/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>chrome-cdp-agent-launcher</string>
  <key>CFBundleIdentifier</key>
  <string>com.local.chrome-dev-cdp-agent</string>
  <key>CFBundleName</key>
  <string>Chrome Dev (CDP Agent)</string>
  <key>CFBundleDisplayName</key>
  <string>Chrome Dev (CDP Agent)</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

  cat > "${macos_dir}/chrome-cdp-agent-launcher" << EOF
#!/usr/bin/env bash
PROFILE_DIR="\${HOME}/.omp/browser-profiles/chrome-cdp-agent"
mkdir -p "\${PROFILE_DIR}"
exec "${CHROME_BIN}" \\
  --user-data-dir="\${PROFILE_DIR}" \\
  --remote-debugging-port=${CDP_PORT} \\
  --no-first-run \\
  --no-default-browser-check \\
  --disable-background-networking \\
  --disable-sync \\
  --password-store=basic \\
  --use-mock-keychain \\
  --window-name="🟢 [CDP Agent] Chrome Dev" \\
  "\$@"
EOF
  chmod +x "${macos_dir}/chrome-cdp-agent-launcher"
  echo "Created standalone wrapper: ${WRAPPER_APP}"
}

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  audit)           cmd_audit "$@" ;;
  launch)          cmd_launch "$@" ;;
  clean)           cmd_clean "$@" ;;
  install-wrapper) cmd_install_wrapper "$@" ;;
  help|--help|-h)  usage ;;
  *)
    echo "Unknown command: ${COMMAND}" >&2
    usage
    exit 1
    ;;
esac
