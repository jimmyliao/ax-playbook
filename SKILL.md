---
name: ax-playbook
description: >-
  Universal OS-aware DX × AX (Developer eXperience × Agent eXperience) diagnostic
  and tuning playbook for Apple Silicon Macs (macOS 26/27 Tahoe) and Ubuntu / WSL2 /
  Linux Cloud Dev-Boxes. Enforces a strict 3-Phase Safety Contract (Phase 1: 100%
  Read-Only Audit -> Phase 2: Impact Table -> Phase 3: Explicit User Consent).
  Use when auditing or tuning macOS or Ubuntu for AI coding agents, Chrome 136+ CDP,
  APFS code_sign_clone bloat, Tmux + JSONL session continuity, Docker candidate hygiene,
  or Apple Foundation Models (/usr/bin/fm).
---

# AX Playbook Skill (`/ax-playbook`)

When invoked via `/ax-playbook` (or when the user asks to audit/tune their Mac or Ubuntu Dev-Box for AI agents), follow this workflow strictly.

## 1. Mandatory 3-Phase Safety Protocol

1. **Phase 1 — Detect OS & Run 100% Read-Only Audit**:
   - Determine the OS via `uname -s` and resolve the directory where `ax-playbook` is located (`PLAYBOOK_DIR`).
   - On **`Darwin` (macOS)**:
     ```bash
     bash "${PLAYBOOK_DIR}/macos/scripts/audit-macos.sh"
     ```
   - On **`Linux` (Ubuntu / Debian / WSL2 / Cloud VM)**:
     ```bash
     bash "${PLAYBOOK_DIR}/ubuntu/scripts/audit-ubuntu.sh"
     ```
   - **Never** run mutating commands (`rm`, `docker prune`, `defaults write`, `kill`, `sudo`) in Phase 1.

2. **Phase 2 — Present Findings & Impact Table**:
   - Summarize the audit output into a clear Markdown table:
     - **Module / Pillar**
     - **Current Status (Measured)**
     - **Recommended Tuning**
     - **Expected Benefit (Latency / Disk Reclaimed / Resilience)**
     - **Risk Level & Reversibility**

3. **Phase 3 — Apply Only User-Approved Modules**:
   - Ask the user which specific items they approve before executing any changes.

---

## 2. Quick Reference by Platform

### On `Darwin` — Lean Agent Mac (`macos/`)
- **Chrome 136+ CDP Isolation & 11.6x Speedup**:
  - Audit: `bash "${PLAYBOOK_DIR}/macos/scripts/tune-chrome-cdp.sh" audit`
  - Launch fast isolated CDP (Port `9222`): `bash "${PLAYBOOK_DIR}/macos/scripts/tune-chrome-cdp.sh" launch`
  - Create `/Applications/Chrome Dev (CDP Agent).app`: `bash "${PLAYBOOK_DIR}/macos/scripts/tune-chrome-cdp.sh" install-wrapper`
- **APFS `code_sign_clone` & Safe Cache Cleanup**:
  - Preview: `bash "${PLAYBOOK_DIR}/macos/scripts/tune-chrome-cdp.sh" clean --dry-run`
  - Apply (after consent): `bash "${PLAYBOOK_DIR}/macos/scripts/tune-chrome-cdp.sh" clean --apply`
- **Spotlight, Menu Bar (`6/4`) & Font Alignment (`Maple Mono NF CN`)**:
  - See [`macos/README.md`](./macos/README.md) Pillar 3.
- **16GB OOM Guard (`cmux-rss-guard`) & Tmux Checkpoint**:
  - Preview Tmux session restore script: `bash "${PLAYBOOK_DIR}/ubuntu/scripts/tmux-agent-checkpoint.sh" --dry-run`
- **macOS 27 `/usr/bin/fm` Readiness**:
  - `exit 69` → user runs `sudo fm license` interactively.
  - `6535` → verify Siri locale is `English (United States)`.
  - Background agents must use `--model system` (`pcc` requires `Terminal.app`).

### On `Linux` — Resilient Agent Dev-Box (`ubuntu/`)
- **Multi-Runtime Tmux × JSONL Checkpoint (`OMP` / `AGY` / `Claude` / `Codex`)**:
  - Dry-run preview: `bash "${PLAYBOOK_DIR}/ubuntu/scripts/tmux-agent-checkpoint.sh" --dry-run`
  - Save atomic checkpoint (with `boot_id` `preboot-*` protection & `flock`): `bash "${PLAYBOOK_DIR}/ubuntu/scripts/tmux-agent-checkpoint.sh"`
- **Docker Candidate & Worktree Disk Hygiene**:
  - Keep `:stable` rollback images and running containers; only prune dangling build cache or obsolete `:candidate` tags after user confirmation.
- **External Dashboard & Tunnel Security Guardrails**:
  - Ensure agent web UIs bind to `127.0.0.1` or Tailscale interface, and enforce an HTTP 401 passcode gate on any external tunnel.

For full architecture and benchmarks, read [`README.md`](./README.md), [`AGENTS.md`](./AGENTS.md), [`macos/README.md`](./macos/README.md), and [`ubuntu/README.md`](./ubuntu/README.md).
