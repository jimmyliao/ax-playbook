# AX Playbook (`ax-playbook`)

> **Developer eXperience (DX) × Agent eXperience (AX)** — The dual-track engineering playbook and self-healing toolkit for running high-density AI Coding Agents (`Claude Code`, `OpenAI Codex`, `Google Antigravity (agy)`, `OMP`) across **Apple Silicon Macs (`macos/`)** and **Ubuntu / WSL2 / Cloud Dev-Boxes (`ubuntu/`)**.

[![Paradigm](https://img.shields.io/badge/Paradigm-DX%20%C3%97%20AX-10b981)](#)
[![macOS](https://img.shields.io/badge/Chapter%201-Lean%20Agent%20Mac%20(macOS%2026%2F27)-000000?logo=apple)](./macos/README.md)
[![Ubuntu](https://img.shields.io/badge/Chapter%202-Resilient%20Agent%20Dev--Box%20(Ubuntu%2FLinux)-E95420?logo=ubuntu)](./ubuntu/README.md)
[![Safety](https://img.shields.io/badge/Agent%20Policy-Audit%20First%20%E2%86%92%20Ask%20Consent-amber)](./AGENTS.md)

---

## Why DX × AX?（為什麼除了 DX，還需要為 AI Agent 打造 AX？）

傳統的 Dotfiles 與系統調校指南只關注 **Developer eXperience (DX)**——字型美觀、Shell 快捷鍵與視窗排版。然而進入多 Agent 協作時代，開發者往往在 **16GB/256GB 的隨身 MacBook** 與 **24×7 常駐的 Ubuntu Cloud Dev-Box** 上同時開啟數十個 Tmux Pane，運行 **OMP、Google Antigravity (`agy`)、Claude Code (`claude`)、OpenAI Codex (`codex`)** 以及 **Chrome CDP 自動化與 Docker Worktree 叢集**。

如果不針對 **Agent eXperience (AX)** 進行底層系統治理，你的機器很快會撞上下列隱形高牆：
- **在 Mac 上（Lean Agent Mac）**：Chrome 136+ 拒絕預設 Profile 的 `--remote-debugging-port`、日常肥大 Profile 讓 Agent 冷啟動卡 5.3 秒、Gatekeeper `code_sign_clone` 偷偷吃掉 12GB 磁碟、失控的 `node` 子程序因 `get-task-allow` 凍死 `WindowServer`。
- **在 Ubuntu Dev-Box 上（Resilient Agent Dev-Box）**：雲端 Spot/Preemptible VM 搶佔重開機後，空白的 Tmux 定時任務瞬間覆蓋重開機前的 24 個 Agent Session 快照；多路 Agent 同時 `git commit` 引發 `.git/index.lock` 競爭失敗；CI/CD `candidate` Docker Image 把磁碟塞爆到 95%+ 導致所有 Agent JSONL 斷寫；對外 Tunnel 裸奔暴露 Agent Console。

**`ax-playbook`** 將我們在真實生產環境（Apple Silicon Mac × Ubuntu Fleet Dev-Box）驗證過的 **DX × AX 雙軌調校架構** 封裝為 **人類可讀指南 (`README.md`) + AI Agent 可直接掛載執行的安全契約 (`AGENTS.md` & `SKILL.md`)**。

---

## 一句話交給你的 AI Agent（1-Liner Agent Prompt）

無論你現在身處 **macOS** 還是 **Ubuntu / Linux / WSL2**，也無論你使用的是 `claude`、`codex`、`agy` 或 `omp`，直接在專案目錄貼上這行指令：

```text
請讀取 @AGENTS.md，先自動偵測我的作業系統（uname -s）並執行對應的 100% 唯讀診斷腳本（macOS 跑 ./macos/scripts/audit-macos.sh，Linux 跑 ./ubuntu/scripts/audit-ubuntu.sh），整理出目前可優化的 DX × AX 項目與預估效益表格，並在取得我明確同意後再逐項套用。
```

> [!IMPORTANT]
> **Audit First → Explain Impact → Explicit User Consent**
> [`AGENTS.md`](./AGENTS.md) 與 [`SKILL.md`](./SKILL.md) 強制規定三階段安全護欄：Phase 1 僅允許執行 100% 唯讀診斷；未經使用者明確點頭，Agent **絕對不會**刪除任何快取、修改系統設定、清理 Docker 映像檔或重啟瀏覽器。

---

## 雙軌架構與實測基準（Dual-Track Architecture & Benchmarks）

### Chapter 1：[`macos/` — Lean Agent Mac](./macos/README.md)（Apple Silicon 16GB / 256GB · macOS 26/27 Tahoe）

| 模組 (Pillar) | 調校前痛點 | DX × AX 調校後實測成果 |
| :--- | :--- | :--- |
| **1. Chrome 136+ CDP 雙實例隔離** | Chrome 136+ 封鎖預設 Profile CDP；日常 Profile 啟動 **5,345 ms**、關閉 **8,002 ms** | 獨立輕量 Profile 冷啟動 **2,801 ms**、關閉 **92 ms**（**87x 加速**）；常駐熱 Attach 僅 **459 ms**（**11.6x 加速**），Dock 獨立翡翠綠 `CDP` 圖示 |
| **2. APFS `code_sign_clone` 與空間治理** | `syspolicyd` 驗證殘留孤兒 bundle + 雙版本 Chrome Framework + 肥大快取佔用 **18 GB+** | 零損書籤/Cookie 回收 `code_sign_clone` (**12.0 GB**)、舊版 Framework (**745 MB**) 與快取 (**5.3 GB**)，搭配 0 額外磁碟的 `fm system` 省下 **+14.3 GB** |
| **3. Spotlight 降噪、Menu Bar 與字型** | `mds_stores` 狂掃 `node_modules`；13/14 吋瀏海裁切圖示；TUI 中英混排表格歪斜 | Spotlight 僅索引 Apps + 系統設定；Menu Bar 緊湊間距 (`6/4`) + AI Quota HUD；`Maple Mono NF CN` 完美對齊 Box-drawing |
| **4. 16GB OOM 防護與 Tmux 開機還原** | 具 `get-task-allow` 的失控 `node` 子程序 (>4GB) 凍死 WindowServer；重開機遺失工作區 | `cmux-rss-guard` 每 30s 巡檢 >4GB 失控子程序並以 `SIGKILL` 保護 UI；`kern.bootsessionuuid` 防覆蓋與 OrbStack 就緒等待 |
| **5. Apple Foundation Models (`fm`)** | `/usr/bin/fm` 秒退 `exit 69`、下載完報 `6535`、背景呼叫 `pcc` 報 `HTTP 503` | 完整解鎖 `sudo fm license` 與 Apple TSS 簽章；釐清背景 Agent `--model system` (**0.764s TTFT**) 與 `Terminal.app` 專屬 `pcc` 邊界 |

👉 **完整指南**：[`macos/README.md`](./macos/README.md)

---

### Chapter 2：[`ubuntu/` — Resilient Agent Dev-Box](./ubuntu/README.md)（Ubuntu / WSL2 / Cloud VM / Headless Fleet）

| 模組 (Pillar) | 調校前痛點 | DX × AX 調校後實測成果 |
| :--- | :--- | :--- |
| **1. 多 Runtime Tmux × JSONL 精準對映** | 單機跑 20+ 個 Agent panes（`omp` / `agy` / `claude` / `codex`），只記 `tmux list-panes` 無法還原對話 ID，還會誤把內部 `__omp_worker` 當成互動式 Session | 透過 `/proc/<pid>/cmdline`、`/proc/<pid>/fd`、Claude PID Registry 與 AGY Presence Lock 雙向反查，100% 精準產出 `cd <cwd> && <agent> --resume <id>`，自動過濾內部 helper workers |
| **2. `boot_id` 防搶佔覆蓋與 `flock` 原子鎖** | Spot VM 搶佔/重開機後，空白的 Tmux 定時任務把重開機前的快照覆蓋歸零；多程序同時寫入/推播快照造成 `.git/index.lock` 損毀 | `tmux-agent-checkpoint.sh` 比對 `/proc/sys/kernel/random/boot_id`，重開機首次執行自動封存 `preboot-<timestamp>.sh`（永久豁免清理），並以 `flock -n` + `mv -f` 確保原子寫入 |
| **3. Docker Candidate 與 Worktree 磁碟治理** | 多路 Agent 平行建置 `*:candidate` 映像檔與 `.worktrees/*`，瞬間把磁碟塞滿至 **95%+**，導致 SQLite / Agent JSONL 寫入失敗 | 自動偵測磁碟/Inode 水位、盤點 dangling build cache 與過期 `candidate` tags，在保留 `stable` rollback 映像的前提下回收 **20–80 GB+** |
| **4. 外部 Dashboard / Tunnel 零信任護欄** | 開發者在雲端開啟 Agent Dashboard 或 Web Preview 時誤綁 `0.0.0.0` 或透過 Cloudflare Tunnel 無驗證裸奔 | 強制 `127.0.0.1` / Tailscale 綁定審計；透過 Tunnel 暴露時強制前置 **HTTP 401 Passcode / Access Gate**，確保 Repo 與快照 100% 零機密外洩 |

👉 **完整指南**：[`ubuntu/README.md`](./ubuntu/README.md)

---

## 儲存庫結構（Repository Layout）

```text
ax-playbook/
├── README.md                        # [DX Entry] 旗艦總覽：DX × AX 雙軌哲學、實測數據表格、1-liner Agent 啟動指令
├── AGENTS.md                        # [AX Entry] 跨平台 (`uname -s`: Darwin vs Linux) AI Agent 互動式調校契約（嚴格三階段安全護欄）
├── SKILL.md                         # [AX Skill] 可攜式 Skill 定義，支援 Claude Code / AGY / OMP / Codex 直接掛載為 `/ax-playbook`
├── macos/                           # Chapter 1: Lean Agent Mac (macOS 26/27 Apple Silicon)
│   ├── README.md                    # macOS 五大調校模組詳解
│   └── scripts/
│       ├── audit-macos.sh           # 100% 唯讀 macOS DX/AX 環境診斷腳本
│       └── tune-chrome-cdp.sh       # Chrome 136+ 隔離 CDP 啟動器、App Wrapper 與安全快取/code_sign_clone 清理工具
└── ubuntu/                          # Chapter 2: Resilient Agent Dev-Box (Ubuntu / WSL2 / Linux Server)
    ├── README.md                    # Ubuntu/Dev-Box 四大韌性模組詳解（Tmux+JSONL、boot_id 防護、Docker 磁碟治理、Tunnel 護欄）
    └── scripts/
        ├── audit-ubuntu.sh          # 100% 唯讀 Ubuntu/Linux DX/AX 診斷腳本（檢查 Tmux、JSONL stores、磁碟/Inode、Docker、開放埠與排程）
        └── tmux-agent-checkpoint.sh # 跨平台可攜式 Tmux × Multi-Agent 快照腳本（含 `boot_id` preboot 封存、原子寫入與 `flock`）
```

---

## 安裝為 Agent Skill（Mounting as `/ax-playbook`）

你可以將本儲存庫直接軟連結至你的全域 Agent Skills 目錄，讓所有專案隨時呼叫 `/ax-playbook`：

```bash
# Clone 儲存庫
git clone https://github.com/jimmyliao/ax-playbook.git ~/workspace/personal/tools/ax-playbook

# 掛載至全域 Skills 目錄（支援 DotAgents / Claude Code / AGY / OMP）
mkdir -p ~/.dotagents/skills ~/.claude/skills
ln -s ~/workspace/personal/tools/ax-playbook ~/.dotagents/skills/ax-playbook
ln -s ~/workspace/personal/tools/ax-playbook ~/.claude/skills/ax-playbook
```

---

## License

MIT License — Built from real-world production engineering across Apple Silicon (`macos/`) and Ubuntu Fleet Dev-Boxes (`ubuntu/`).
