#!/usr/bin/env bash
# ==============================================================================
# tmux-agent-checkpoint.sh — Portable Host-Isolated Tmux × Multi-Agent Checkpoint
# ==============================================================================
# Part of ax-playbook (Chapter 2: Resilient Agent Dev-Box & Chapter 1: Lean Mac)
#
# Features:
#   1. Multi-Runtime Agent Discovery:
#      Maps each tmux pane to its active top-level AI agent (`omp`, `agy`,
#      `claude`, `codex`) and resolves the exact session/conversation ID via
#      process argv, open file descriptors (.jsonl / .db), or lockfiles, while
#      ignoring internal helper workers (`__omp_worker`, `daemon_broker`, etc.).
#   2. Boot-ID Preemption / Reboot Protection (`preboot-*`):
#      Compares current kernel boot ID (`/proc/sys/kernel/random/boot_id` on
#      Linux, `sysctl -n kern.bootsessionuuid` on macOS) against the last saved
#      boot ID. On a fresh boot, automatically archives the previous healthy
#      restore script & JSON manifest to `preboot-<host>-<timestamp>.{sh,json}`
#      (exempt from rotation) BEFORE writing any post-reboot state.
#   3. Concurrency & Atomic Write Guard (`flock` + `mktemp` + `mv -f`):
#      Acquires a non-blocking exclusive lock (`flock` or atomic `mkdir` fallback),
#      validates generated script syntax (`bash -n`), and atomically replaces
#      the target restore script and JSON manifest under `0700` / `0600` perms.
#   4. Zero Secret Exposure:
#      Never captures full process environment or raw command-like pane titles;
#      sanitizes session/window names and paths (`redact_secrets`) and strictly
#      extracts validated UUIDs and `.jsonl` paths.
#      In `--dry-run` mode, runs 100% in memory (zero files/locks created).
# ==============================================================================

set -euo pipefail
umask 077

DRY_RUN=0
QUIET=0
CHECKPOINT_DIR="${AX_CHECKPOINT_DIR:-$HOME/.local/state/ax-playbook/tmux-restores}"
MAX_HISTORY="${AX_MAX_HISTORY:-20}"

usage() {
  cat << 'EOF'
Usage: ./ubuntu/scripts/tmux-agent-checkpoint.sh [options]

Options:
  --dry-run             Inspect active tmux sessions/panes in memory and print
                        the generated restore script to stdout (100% zero disk writes).
  --dir=PATH            Override output directory
                        (default: ~/.local/state/ax-playbook/tmux-restores)
  --quiet               Suppress informational output (useful for cron/LaunchAgent)
  -h, --help            Show this help message
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --quiet)   QUIET=1 ;;
    --dir=*)   CHECKPOINT_DIR="${arg#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $arg" >&2
      usage
      exit 1
      ;;
  esac
done

log_info() {
  [ "$QUIET" -eq 1 ] && return 0
  printf "[tmux-agent-checkpoint] %s\n" "$1" >&2
}

# Redact query strings, tokens, keys, passwords, or Bearer strings
redact_secrets() {
  local input="$1"
  echo "$input" | sed -E \
    -e 's/([?&](token|access_token|api_key|key|secret|password|sig)=)[^ &"'\'']+/\1[REDACTED]/Ig' \
    -e 's/(--(token|api-key|secret|password)[= ])[^ "'\'']+/\1[REDACTED]/Ig' \
    -e 's/(Bearer )[A-Za-z0-9._-]+/\1[REDACTED]/g' \
    -e 's/(sk-[A-Za-z0-9_-]{16,})/[REDACTED]/g'
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/ }"
  s="${s//$'\r'/ }"
  s="${s//$'\t'/ }"
  printf "%s" "$s"
}

# ------------------------------------------------------------------------------
# 1. Resolve Stable Host Identifier & Kernel Boot ID
# ------------------------------------------------------------------------------
resolve_host_id() {
  local h=""
  if [ "$(uname -s)" = "Darwin" ] && command -v scutil >/dev/null 2>&1; then
    h="$(scutil --get LocalHostName 2>/dev/null || true)"
  fi
  if [ -z "$h" ]; then
    h="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "default-host")"
  fi
  echo "$h" | tr -cd 'a-zA-Z0-9_-'
}

resolve_boot_id() {
  if [ -r /proc/sys/kernel/random/boot_id ]; then
    cat /proc/sys/kernel/random/boot_id 2>/dev/null | tr -d '[:space:]'
  elif command -v sysctl >/dev/null 2>&1; then
    sysctl -n kern.bootsessionuuid 2>/dev/null | tr -d '[:space:]' || echo "unknown-boot"
  else
    echo "unknown-boot"
  fi
}

HOST_ID="$(resolve_host_id)"
BOOT_ID="$(resolve_boot_id)"
NOW_ISO="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
NOW_STAMP="$(date -u '+%Y%m%d-%H%M%S')"

# Verify tmux server is running before doing anything
if ! command -v tmux >/dev/null 2>&1 || ! tmux list-sessions >/dev/null 2>&1; then
  log_info "No active tmux sessions found for UID $(id -u). Exiting without overwriting checkpoints."
  exit 0
fi

# ------------------------------------------------------------------------------
# 2. Acquire Exclusive Non-Blocking Lock (Strictly skipped in --dry-run)
# ------------------------------------------------------------------------------
LOCK_FILE="/tmp/tmux-agent-checkpoint-$(id -u).lock"
LOCK_DIR="/tmp/tmux-agent-checkpoint-$(id -u).lockdir"
OWNS_LOCK_DIR=0

cleanup_lock() {
  if [ "$OWNS_LOCK_DIR" -eq 1 ]; then
    rm -rf "$LOCK_DIR" 2>/dev/null || true
  fi
}

if [ "$DRY_RUN" -eq 0 ]; then
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
      log_info "Another checkpoint instance is already running (flock busy). Exiting."
      exit 0
    fi
  else
    # Portable atomic mkdir fallback for macOS without flock
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
      if [ -f "$LOCK_DIR/pid" ]; then
        OLD_PID="$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")"
        if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
          log_info "Another checkpoint instance (PID ${OLD_PID}) is running. Exiting."
          exit 0
        fi
      fi
      rm -rf "$LOCK_DIR" 2>/dev/null || true
      mkdir "$LOCK_DIR"
    fi
    OWNS_LOCK_DIR=1
    echo "$$" > "$LOCK_DIR/pid"
    trap cleanup_lock EXIT INT TERM
  fi
fi

# ------------------------------------------------------------------------------
# 3. Helper: Inspect Process Tree & Resolve Agent Resume Command per Pane
# ------------------------------------------------------------------------------
get_cmdline() {
  local pid="$1"
  if [ -r "/proc/${pid}/cmdline" ]; then
    tr '\0' ' ' < "/proc/${pid}/cmdline" 2>/dev/null || true
  else
    ps -p "$pid" -o args= 2>/dev/null || true
  fi
}

find_open_file_matching() {
  local pid="$1"
  local pattern="$2"
  if [ -d "/proc/${pid}/fd" ]; then
    ls -l "/proc/${pid}/fd" 2>/dev/null | awk -v pat="$pattern" '$0 ~ pat {print $NF; exit}' || true
  elif command -v lsof >/dev/null 2>&1; then
    lsof -p "$pid" -Fn 2>/dev/null | sed -n 's/^n//p' | grep -E "$pattern" | head -n 1 || true
  fi
}

resolve_pane_agent() {
  local shell_pid="$1"
  local pane_tty="$2"
  local pane_cwd="$3"
  local tty_short="${pane_tty#/dev/}"

  local pids=()
  while IFS= read -r p; do
    [ -n "$p" ] && pids+=("$p")
  done < <(ps -t "$tty_short" -o pid= 2>/dev/null | awk '{print $1}' || pgrep -P "$shell_pid" 2>/dev/null || true)

  local resolved_cmd=""
  for pid in "${pids[@]+"${pids[@]}"}"; do
    [ "$pid" = "$shell_pid" ] && continue
    local args
    args="$(get_cmdline "$pid")"
    [ -z "$args" ] && continue

    # Skip internal OMP helper workers
    case "$args" in
      *__omp_worker*|*daemon_broker*|*js_eval*|*text_predict*|*browser-relay*)
        continue
        ;;
    esac

    # 1. Google Antigravity (`agy`)
    if echo "$args" | grep -Eq '(^|[ /])agy( |$)'; then
      local conv_id=""
      conv_id="$(echo "$args" | grep -Eo -- '--conversation[= ][0-9a-fA-F-]{36}' | head -n 1 | grep -Eo '[0-9a-fA-F-]{36}' || true)"
      if [ -z "$conv_id" ]; then
        local db_file
        db_file="$(find_open_file_matching "$pid" '\.gemini/antigravity-cli/conversations/[0-9a-fA-F-]{36}\.(db|lock)$')"
        if [ -n "$db_file" ]; then
          conv_id="$(basename "$db_file" | sed -E 's/\.(db|lock)$//')"
        fi
      fi
      if [ -n "$conv_id" ]; then
        resolved_cmd="agy --conversation ${conv_id}"
      else
        resolved_cmd="agy"
      fi
      break
    fi

    # 2. OMP (`omp`)
    if echo "$args" | grep -Eq '(^|[ /])omp( |$)'; then
      local omp_target=""
      omp_target="$(echo "$args" | sed -nE 's/.*--resume[= ]([^ ]+\.jsonl|[0-9a-fA-F-]{36}).*/\1/p' | head -n 1 || true)"
      if [ -z "$omp_target" ]; then
        omp_target="$(find_open_file_matching "$pid" '\.omp/agent/sessions/.*\.jsonl$' || true)"
      fi
      if [ -n "$omp_target" ]; then
        resolved_cmd="omp --resume ${omp_target}"
      else
        resolved_cmd="omp --continue"
      fi
      break
    fi

    # 3. Claude Code (`claude`)
    if echo "$args" | grep -Eq '(^|[ /])claude( |$)'; then
      local claude_id=""
      claude_id="$(echo "$args" | grep -Eo -- '(--resume|-r)[= ][0-9a-fA-F-]{36}' | head -n 1 | grep -Eo '[0-9a-fA-F-]{36}' || true)"
      if [ -z "$claude_id" ] && [ -f "$HOME/.claude/sessions/${pid}.json" ]; then
        claude_id="$(grep -Eo '[0-9a-fA-F-]{36}' "$HOME/.claude/sessions/${pid}.json" 2>/dev/null | head -n 1 || true)"
      fi
      if [ -z "$claude_id" ]; then
        local cl_file
        cl_file="$(find_open_file_matching "$pid" '\.claude/projects/.*/[0-9a-fA-F-]{36}\.jsonl$' || true)"
        if [ -n "$cl_file" ]; then
          claude_id="$(basename "$cl_file" .jsonl)"
        fi
      fi
      if [ -n "$claude_id" ]; then
        resolved_cmd="claude --resume ${claude_id}"
      else
        resolved_cmd="claude --continue"
      fi
      break
    fi

    # 4. OpenAI Codex (`codex`)
    if echo "$args" | grep -Eq '(^|[ /])codex( |$)'; then
      local codex_id=""
      codex_id="$(echo "$args" | grep -Eo 'resume [0-9a-fA-F-]{36}' | head -n 1 | grep -Eo '[0-9a-fA-F-]{36}' || true)"
      if [ -z "$codex_id" ]; then
        local cx_file
        cx_file="$(find_open_file_matching "$pid" '\.codex/sessions/.*/rollout-.*\.jsonl$' || true)"
        if [ -n "$cx_file" ]; then
          codex_id="$(basename "$cx_file" .jsonl | grep -Eo '[0-9a-fA-F-]{36}' | head -n 1 || true)"
        fi
      fi
      if [ -n "$codex_id" ]; then
        resolved_cmd="codex resume ${codex_id}"
      else
        resolved_cmd="codex"
      fi
      break
    fi
  done

  redact_secrets "$resolved_cmd"
}

# ------------------------------------------------------------------------------
# 4. Build the Restore Script & JSON Manifest in Memory
# ------------------------------------------------------------------------------
TOTAL_SESSIONS="$(tmux list-sessions 2>/dev/null | wc -l | tr -d ' ')"
TOTAL_WINDOWS="$(tmux list-windows -a 2>/dev/null | wc -l | tr -d ' ')"
TOTAL_PANES="$(tmux list-panes -a 2>/dev/null | wc -l | tr -d ' ')"

SCRIPT_LINES=()
SCRIPT_LINES+=("#!/usr/bin/env bash")
SCRIPT_LINES+=("# ==============================================================================")
SCRIPT_LINES+=("# Auto-generated Tmux × Multi-Agent Restore Script")
SCRIPT_LINES+=("# Host       : ${HOST_ID}")
SCRIPT_LINES+=("# Boot-ID    : ${BOOT_ID}")
SCRIPT_LINES+=("# Timestamp  : ${NOW_ISO}")
SCRIPT_LINES+=("# Topology   : ${TOTAL_SESSIONS} session(s), ${TOTAL_WINDOWS} window(s), ${TOTAL_PANES} pane(s)")
SCRIPT_LINES+=("# ==============================================================================")
SCRIPT_LINES+=("set -euo pipefail")
SCRIPT_LINES+=("")

JSON_PANES=()
AGENT_COUNT=0

while IFS=$'\t' read -r raw_sess_name; do
  [ -z "$raw_sess_name" ] && continue
  sess_name="$(redact_secrets "$raw_sess_name")"
  SCRIPT_LINES+=("# --- Session: ${sess_name} ---")

  first_win=1
  while IFS=$'\t' read -r win_idx raw_win_name win_layout; do
    [ -z "$win_idx" ] && continue
    win_name="$(redact_secrets "$raw_win_name")"

    first_pane_cwd="$(tmux list-panes -t "${raw_sess_name}:${win_idx}" -F '#{pane_current_path}' 2>/dev/null | head -n 1 || echo "$HOME")"
    [ -z "$first_pane_cwd" ] && first_pane_cwd="$HOME"
    first_pane_cwd="$(redact_secrets "$first_pane_cwd")"

    if [ "$first_win" -eq 1 ]; then
      SCRIPT_LINES+=("$(printf "if ! tmux has-session -t %q 2>/dev/null; then" "$sess_name")")
      SCRIPT_LINES+=("$(printf "  tmux new-session -d -s %q -n %q -c %q" "$sess_name" "$win_name" "$first_pane_cwd")")
      SCRIPT_LINES+=("fi")
      first_win=0
    else
      SCRIPT_LINES+=("$(printf "tmux new-window -t %q -n %q -c %q || true" "${sess_name}:${win_idx}" "$win_name" "$first_pane_cwd")")
    fi

    pane_seq=0
    while IFS=$'\t' read -r pane_idx pane_pid pane_tty raw_pane_cwd pane_cmd; do
      [ -z "$pane_idx" ] && continue
      pane_cwd="$(redact_secrets "$raw_pane_cwd")"
      if [ "$pane_seq" -gt 0 ]; then
        SCRIPT_LINES+=("$(printf "tmux split-window -t %q -c %q || true" "${sess_name}:${win_idx}" "$pane_cwd")")
      fi

      agent_resume="$(resolve_pane_agent "$pane_pid" "$pane_tty" "$pane_cwd")"
      if [ -n "$agent_resume" ]; then
        AGENT_COUNT=$(( AGENT_COUNT + 1 ))
        SCRIPT_LINES+=("$(printf "# Pane %s:%s.%s (%s) -> %s" "$sess_name" "$win_idx" "$pane_idx" "$pane_cmd" "$agent_resume")")
        SCRIPT_LINES+=("# To resume agent in this pane, uncomment or run:")
        SCRIPT_LINES+=("$(printf "# tmux send-keys -t %q %q C-m" "${sess_name}:${win_idx}.${pane_idx}" "cd $(printf '%q' "$pane_cwd") && ${agent_resume}")")
      fi

      JSON_PANES+=("$(printf '    {"target":"%s","window_name":"%s","cwd":"%s","command":"%s","agent_resume":"%s"}' \
        "$(json_escape "${sess_name}:${win_idx}.${pane_idx}")" \
        "$(json_escape "$win_name")" \
        "$(json_escape "$pane_cwd")" \
        "$(json_escape "$pane_cmd")" \
        "$(json_escape "$agent_resume")")")

      pane_seq=$(( pane_seq + 1 ))
    done < <(tmux list-panes -t "${raw_sess_name}:${win_idx}" -F $'#{pane_index}\t#{pane_pid}\t#{pane_tty}\t#{pane_current_path}\t#{pane_current_command}' 2>/dev/null)

    if [ -n "$win_layout" ]; then
      SCRIPT_LINES+=("$(printf "tmux select-layout -t %q %q 2>/dev/null || true" "${sess_name}:${win_idx}" "$win_layout")")
    fi
    SCRIPT_LINES+=("")
  done < <(tmux list-windows -t "$raw_sess_name" -F $'#{window_index}\t#{window_name}\t#{window_layout}' 2>/dev/null)
done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)

SCRIPT_CONTENT="$(printf "%s\n" "${SCRIPT_LINES[@]}")"

# Validate generated shell script syntax in memory via stdin (zero temp files!)
printf "%s\n" "$SCRIPT_CONTENT" | bash -n

if [ "$DRY_RUN" -eq 1 ]; then
  log_info "Dry-run complete (0 files written): ${TOTAL_SESSIONS} session(s), ${TOTAL_WINDOWS} window(s), ${TOTAL_PANES} pane(s), ${AGENT_COUNT} agent(s) resolved."
  printf "%s\n" "$SCRIPT_CONTENT"
  exit 0
fi

# ------------------------------------------------------------------------------
# 5. Boot-ID Preboot Archiving & Atomic Replace (Script + JSON Manifest)
# ------------------------------------------------------------------------------
mkdir -p "$CHECKPOINT_DIR"
chmod 700 "$CHECKPOINT_DIR" 2>/dev/null || true

TARGET_SH="${CHECKPOINT_DIR}/${HOST_ID}.sh"
TARGET_JSON="${CHECKPOINT_DIR}/${HOST_ID}.json"
BOOT_STATE_FILE="${CHECKPOINT_DIR}/${HOST_ID}.boot_id"
HISTORY_DIR="${CHECKPOINT_DIR}/history-${HOST_ID}"
mkdir -p "$HISTORY_DIR"

LAST_BOOT_ID=""
if [ -f "$BOOT_STATE_FILE" ]; then
  LAST_BOOT_ID="$(cat "$BOOT_STATE_FILE" 2>/dev/null | tr -d '[:space:]' || true)"
fi

# If a previous checkpoint exists and boot_id changed, preserve permanent preboot-* archives!
if [ -f "$TARGET_SH" ] && [ -n "$LAST_BOOT_ID" ] && [ "$LAST_BOOT_ID" != "$BOOT_ID" ]; then
  PREBOOT_SH="${CHECKPOINT_DIR}/preboot-${HOST_ID}-${NOW_STAMP}.sh"
  cp -p "$TARGET_SH" "$PREBOOT_SH"
  chmod 600 "$PREBOOT_SH"
  if [ -f "$TARGET_JSON" ]; then
    PREBOOT_JSON="${CHECKPOINT_DIR}/preboot-${HOST_ID}-${NOW_STAMP}.json"
    cp -p "$TARGET_JSON" "$PREBOOT_JSON"
    chmod 600 "$PREBOOT_JSON"
  fi
  log_info "Boot-ID change detected (${LAST_BOOT_ID} -> ${BOOT_ID})! Preserved pre-reboot checkpoint at ${PREBOOT_SH}"
fi

# Write script & JSON manifest atomically via mktemp inside CHECKPOINT_DIR
TMP_SH="$(mktemp "${CHECKPOINT_DIR}/.tmp-${HOST_ID}-sh.XXXXXX")"
TMP_JSON="$(mktemp "${CHECKPOINT_DIR}/.tmp-${HOST_ID}-json.XXXXXX")"

printf "%s\n" "$SCRIPT_CONTENT" > "$TMP_SH"
chmod 700 "$TMP_SH"

{
  printf "{\n"
  printf '  "host": "%s",\n' "$(json_escape "$HOST_ID")"
  printf '  "boot_id": "%s",\n' "$(json_escape "$BOOT_ID")"
  printf '  "timestamp": "%s",\n' "$(json_escape "$NOW_ISO")"
  printf '  "sessions": %d,\n' "$TOTAL_SESSIONS"
  printf '  "windows": %d,\n' "$TOTAL_WINDOWS"
  printf '  "panes": %d,\n' "$TOTAL_PANES"
  printf '  "agents_resolved": %d,\n' "$AGENT_COUNT"
  printf '  "pane_inventory": [\n'
  pane_total="${#JSON_PANES[@]}"
  idx=0
  for jp in "${JSON_PANES[@]+"${JSON_PANES[@]}"}"; do
    idx=$(( idx + 1 ))
    if [ "$idx" -lt "$pane_total" ]; then
      printf "%s,\n" "$jp"
    else
      printf "%s\n" "$jp"
    fi
  done
  printf "  ]\n"
  printf "}\n"
} > "$TMP_JSON"
chmod 600 "$TMP_JSON"

echo "$BOOT_ID" > "${BOOT_STATE_FILE}.tmp"
mv -f "${BOOT_STATE_FILE}.tmp" "$BOOT_STATE_FILE"

cp -p "$TMP_SH" "${HISTORY_DIR}/${NOW_STAMP}.sh"
cp -p "$TMP_JSON" "${HISTORY_DIR}/${NOW_STAMP}.json"
mv -f "$TMP_SH" "$TARGET_SH"
mv -f "$TMP_JSON" "$TARGET_JSON"

# Rotate non-preboot history snapshots beyond MAX_HISTORY
ls -1t "${HISTORY_DIR}"/*.sh 2>/dev/null | tail -n +$(( MAX_HISTORY + 1 )) | while IFS= read -r old_f; do
  [ -n "$old_f" ] || continue
  rm -f "$old_f" "${old_f%.sh}.json"
done

log_info "Saved checkpoint to ${TARGET_SH} & ${TARGET_JSON} (${TOTAL_SESSIONS} sessions, ${TOTAL_PANES} panes, ${AGENT_COUNT} agents)."
