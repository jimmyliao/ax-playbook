# AGENTS.md — Universal OS-Aware DX × AX Interactive Playbook

> **Target Audience**: AI Coding Agents (`Claude Code`, `OpenAI Codex`, `Google Antigravity (agy)`, `OMP`, `Cursor`, `Windsurf`) assisting a developer on **macOS (`Darwin`)** or **Ubuntu / Linux / WSL2 (`Linux`)**.

---

## 0. Mandatory 3-Phase Safety Contract (MUST FOLLOW WITHOUT EXCEPTION)

Whenever a user asks you to *"Read `@AGENTS.md` and audit/tune my machine"* (or invokes `/ax-playbook`), you **MUST** strictly follow this **3-Phase Protocol**:

### Phase 1 — OS Detection & 100% Read-Only Audit First
1. Detect the host OS via `uname -s`:
   - **`Darwin` (macOS)**: Run `./macos/scripts/audit-macos.sh` (and `./macos/scripts/tune-chrome-cdp.sh audit` if Chrome is installed).
   - **`Linux` (Ubuntu / Debian / WSL2 / Headless Server)**: Run `./ubuntu/scripts/audit-ubuntu.sh`.
2. **STRICT READ-ONLY BOUNDARY**: During Phase 1, you **MUST NOT** execute any mutating commands (`rm`, `docker rmi`, `docker system prune`, `defaults write`, `launchctl`, `systemctl`, `crontab`, `kill`, or `sudo`).

### Phase 2 — Structured Impact & Risk Table
Present a concise Markdown summary table tailored to the detected OS:

| Pillar / Module | Current State (Measured) | Recommended Action | Expected Gain (Speed / Disk / Resilience) | Risk & Reversibility |
| :--- | :--- | :--- | :--- | :--- |

### Phase 3 — Explicit Per-Module User Approval
- Ask the user **which specific modules** they want to execute before running any state-changing command.
- **Data Loss Prevention Guardrails**:
  - **macOS**: Never delete user browser data (`Bookmarks`, `Cookies`, `Login Data`, `History`, `Extensions`), never kill an active personal browser without consent, and never overwrite existing `LaunchAgents` without backing them up first.
  - **Ubuntu / Linux**: Never kill active `tmux` sessions or running containers, never prune `stable` / active Docker images without explicit confirmation, never expose local ports to `0.0.0.0` without an authentication gate, and never include tokens, credentials, or query strings in checkpoint files.

---

## Track A: `Darwin` — Lean Agent Mac (`macos/`)

When `uname -s` is `Darwin`, guide the user through the **5 Pillars of Lean Agent Mac** (detailed in [`macos/README.md`](./macos/README.md)):

### Pillar A1 — Chrome 136+ CDP Dual-Instance Isolation & 11.6x Speedup (AX)
- **Root Cause**: Chrome 136+ blocks `--remote-debugging-port` on default user data directories (`~/Library/Application Support/Google/Chrome*`), and daily profiles with heavy extensions/Service Workers cause `5.3s+` cold starts and `8.0s` shutdown hangs.
- **Action Plan (After User Consent)**:
  ```bash
  # 1. Read-only audit of Chrome CDP port & profile bloat
  ./macos/scripts/tune-chrome-cdp.sh audit

  # 2. Launch isolated fast CDP instance on port 9222 (~459ms warm attach)
  ./macos/scripts/tune-chrome-cdp.sh launch

  # 3. Optional: Install standalone '/Applications/Chrome Dev (CDP Agent).app' wrapper
  ./macos/scripts/tune-chrome-cdp.sh install-wrapper
  ```

### Pillar A2 — APFS `code_sign_clone` & Safe Cache Hygiene (Storage)
- **Root Cause**: Gatekeeper (`syspolicyd`) leaves orphaned `*.code_sign_clone` bundles (`5–15 GB`) under `/private/var/folders/*/*/X/`; Chrome retains previous Framework versions (`~750 MB`); transient `Service Worker/CacheStorage` and `GPUCache` grow to `3–6 GB`.
- **Action Plan (After User Consent)**:
  ```bash
  # Always run dry-run first and show exact reclaimable sizes
  ./macos/scripts/tune-chrome-cdp.sh clean --dry-run

  # Only after explicit approval:
  ./macos/scripts/tune-chrome-cdp.sh clean --apply
  ```

### Pillar A3 — System UI, Spotlight Apps-Only & Terminal Typography (DX)
- **Action Plan (After User Consent)**:
  1. **Compact Menu Bar Spacing (`6/4`)**:
     ```bash
     defaults -currentHost write -globalDomain NSStatusItemSpacing -int 6
     defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 4
     killall ControlCenter
     ```
  2. **Spotlight Developer Noise Suppression (`.metadata_never_index`)**:
     ```bash
     for d in "$HOME/.cache" "$HOME/.npm" "$HOME/.nvm" "$HOME/.cargo" "$HOME/.gradle" "$HOME/.ollama"; do
       [ -d "$d" ] && touch "$d/.metadata_never_index"
     done
     ```
  3. **Terminal Font Alignment**: Recommend `Maple Mono NF CN` (`font-family = Maple Mono NF CN`, `font-thicken = true` in `~/.config/ghostty/config`) for pixel-aligned CJK + Unicode box-drawing tables.

### Pillar A4 — 16GB OOM Guard (`cmux-rss-guard`) & Tmux Reboot Resilience (AX)
- **Action Plan (After User Consent)**:
  1. Use `scutil --get LocalHostName` instead of DHCP-volatile `hostname -s`.
  2. Run `./ubuntu/scripts/tmux-agent-checkpoint.sh --dry-run` (cross-platform compatible on both macOS and Linux!) to preview Tmux × Agent session recovery commands with `kern.bootsessionuuid` protection.
  3. On 16GB Macs, offer a lightweight 30s RSS guard (`cmux-rss-guard`) that terminates runaway child `node` processes exceeding `4 GB RSS` (`4194304 KB`) before `WindowServer` freezes.

### Pillar A5 — macOS 27 Native Apple Foundation Models (`/usr/bin/fm`) Readiness (AX)
- **Action Plan**:
  - If `/usr/bin/fm models` exits `69` (`EX_UNAVAILABLE`), instruct the user to run `sudo fm license` interactively in their terminal.
  - If model download is `97/97` but returns `SecureUnableToPersonalize (6535)`, instruct the user to verify Siri language is `English (United States)` and toggle Apple Intelligence off/on.
  - Ensure background agents and scripts always pass `--model system` (`~0.76s` TTFT, 0 extra disk). Calling `--model pcc` outside native `Terminal.app` returns `HTTP 503`.

---

## Track B: `Linux` — Resilient Agent Dev-Box (`ubuntu/`)

When `uname -s` is `Linux`, guide the user through the **4 Pillars of Resilient Agent Dev-Box** (detailed in [`ubuntu/README.md`](./ubuntu/README.md)):

### Pillar B1 — Multi-Runtime Tmux × JSONL Session Continuity (`OMP` / `AGY` / `Claude` / `Codex`)
- **Why This Matters**: A headless Dev-Box often runs 20+ concurrent agent panes across `tmux`. Standard `tmux-resurrect` only restores shells—it loses the exact conversation/session UUIDs and mistakenly treats internal helper processes (like OMP `__omp_worker`, `daemon_broker`, `js_eval`) as interactive sessions.
- **Action Plan (After User Consent)**:
  ```bash
  # 1. Preview discovered tmux panes and resolved agent resume commands (Read-Only Dry-Run)
  ./ubuntu/scripts/tmux-agent-checkpoint.sh --dry-run

  # 2. Write atomic host-isolated checkpoint script & JSON manifest
  ./ubuntu/scripts/tmux-agent-checkpoint.sh
  ```

### Pillar B2 — Preemption / Reboot Protection (`boot_id` / `preboot-*`) & Atomic `flock`
- **Why This Matters**: When a Cloud VM (GCP/AWS Spot or Preemptible instance) or WSL2 host reboots, a cron job running every 15 minutes will otherwise overwrite the last healthy pre-reboot checkpoint with an empty post-reboot tmux state. Concurrent git syncs can also leave stale `.git/index.lock` files.
- **Action Plan (After User Consent)**:
  - Verify `/proc/sys/kernel/random/boot_id` tracking is enabled via `./ubuntu/scripts/tmux-agent-checkpoint.sh`. Whenever `boot_id` changes, the script automatically archives the previous restore script to `preboot-<timestamp>.sh` (exempt from rotation) and uses `flock -n` + atomic `mv -f`.
  - Offer to install a user-level cron entry (every 15 minutes) only after user confirmation:
    ```cron
    */15 * * * * flock -n /tmp/tmux-agent-checkpoint.lock /path/to/ax-playbook/ubuntu/scripts/tmux-agent-checkpoint.sh >/dev/null 2>&1
    ```

### Pillar B3 — Docker Candidate Image & Git Worktree Storage Hygiene
- **Why This Matters**: Multi-agent CI/CD workflows frequently build `*:candidate` images alongside `*:stable` images and spawn multiple `.worktrees/*`. If disk usage crosses **95%**, agent JSONL session logs and SQLite databases fail mid-turn.
- **Action Plan (After User Consent)**:
  1. Review the disk, inode, Docker storage (`docker system df`), and git worktree report from `./ubuntu/scripts/audit-ubuntu.sh`.
  2. Propose a safe, non-destructive cleanup plan:
     - Keep running containers and `:stable` rollback tags untouched.
     - Preview dangling images (`docker images -f "dangling=true"`), build cache (`docker builder prune`), and merged/stale worktrees (`git worktree list`) before asking the user for approval to prune.

### Pillar B4 — External Dashboard & Tunnel Security Guardrails (Zero Secret Exposure)
- **Why This Matters**: Exposing local agent dashboards, preview servers, or WebSockets on `0.0.0.0` or via public tunnels (`cloudflared`, `ngrok`, `tailscale Funnel`) without an authentication gate leaks internal state.
- **Action Plan (After User Consent)**:
  1. Inspect listening TCP sockets reported by `./ubuntu/scripts/audit-ubuntu.sh` (`ss -tulpn`).
  2. Recommend binding internal agent services strictly to `127.0.0.1` or the Tailscale interface (`100.x.y.z`).
  3. For any service routed through an external tunnel, require an **HTTP 401 Passcode / Access Gate** in front of the upstream port and verify zero tokens or credentials exist in environment titles or tracked files.
