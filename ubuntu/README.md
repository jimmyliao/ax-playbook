# Chapter 2: Resilient Agent Dev-Box (`ubuntu/`)

> **Developer eXperience (DX) × Agent eXperience (AX) on Ubuntu / WSL2 / Cloud VM / Headless Fleet** — 專為 24×7 常駐多路 AI Coding Agents（`OMP`、`Google Antigravity (agy)`、`Claude Code (claude)`、`OpenAI Codex (codex)`）打造的 **Tmux × JSONL 跨重開機連續性、Spot/Preemptible `boot_id` 防搶佔覆蓋、Docker `candidate` 磁碟水位治理、與外部 Tunnel 零信任護欄** 實戰指南。

[![Platform](https://img.shields.io/badge/Ubuntu%20%2F%20Linux-22.04%20%7C%2024.04%20%7C%20WSL2-E95420?logo=ubuntu)](#)
[![Continuity](https://img.shields.io/badge/Tmux%20%C3%97%20JSONL-OMP%20%7C%20AGY%20%7C%20Claude%20%7C%20Codex-3b82f6)](#)
[![Paradigm](https://img.shields.io/badge/Paradigm-DX%20%C3%97%20AX-10b981)](#)
[![Safety](https://img.shields.io/badge/Agent%20Policy-Audit%20First%20%E2%86%92%20Ask%20Consent-amber)](../AGENTS.md)

---

## Why Resilient Agent Dev-Box?（為什麼雲端 / Linux Dev-Box 需要 AX 韌性調校？）

當你把 Ubuntu Cloud VM（GCP / AWS / Hetzner）、WSL2 或家用 Linux 伺服器當作 24×7 的 **Agent Fleet Dev-Box** 時，單機往往同時開啟 **8–10 個 Tmux Sessions、25–30 個 Panes**，常駐超過 **20 個頂層 AI Agents**，並透過 Git Worktrees 與 Docker 平行驗證多個專案。

傳統 Linux 伺服器設定只顧及 SSH 連線與基礎套件（DX），卻會在下列四大 **AX 災難場景** 中瞬間崩潰：

| 維度 | 傳統 Linux Dev-Box 痛點 | DX × AX 調校後效果（Ubuntu Fleet 實戰驗證） |
| :--- | :--- | :--- |
| **1. 多 Runtime Tmux × JSONL 狀態對映** | `tmux-resurrect` 只會還原空殼 `zsh`；重開機後 24 個正在跑的 `omp`、`agy`、`claude`、`codex` 對話 ID 全部失聯，或誤把 OMP 內部 `__omp_worker` 當成互動式 Session | **TTY + `/proc` + Lockfile 雙向反查**：自動解析每個 Pane 下的子程序樹、開啟的 `.jsonl` 檔案、Claude PID Registry 與 AGY Presence Lock，精準產出 `cd <cwd> && <agent> --resume <id>` 並排除 helper workers |
| **2. VM 搶佔 / 重開機防覆蓋 (`boot_id`) 與原子鎖 (`flock`)** | 雲端 VM 因維護或 Spot Preemption 重開機後，每 15 分鐘跑一次的 cron 腳本抓到「空白或僅 1 個新 tmux session」，直接把重開機前 24 個 Agents 的快照覆蓋歸零；多程序同時 commit 引發 `.git/index.lock` 殘留 | **`/proc/sys/kernel/random/boot_id` 防護**：偵測到 `boot_id` 改變時，先將重開機前最後一份健康快照永久封存為 `preboot-<timestamp>.sh`（豁免滾動刪除）；全程以 `flock -n` + `mktemp` + `mv -f` 原子更新 |
| **3. Docker `candidate` 映像檔與 Worktree 磁碟風暴** | CI/CD 蓝綠部署或多路 Agent 頻繁建置 `*:candidate` 映像檔與 `.worktrees/*`，瞬間把磁碟塞爆至 **95%+**，導致 Agent JSONL 斷寫、SQLite `database or disk is full` | **分層空間治理**：自動監控磁碟/Inode 水位（85% 預警 / 95% 危急），保留 `:stable` 退版映像與運行中容器，精準回收 dangling cache 與過期 `candidate` 映像（單次回收 **20–80 GB**） |
| **4. 外部 Dashboard / Tunnel 零信任護欄** | Agent 啟動 Web Preview 或監控面板時綁定 `0.0.0.0`，或透過 Cloudflare Tunnel / ngrok 直接暴露無驗證端點；Pane title 意外記錄含 Token 的命令列 | **Passcode Gate + 零機密外洩**：強制內部服務綁定 `127.0.0.1` 或 Tailscale 介面；對外 Tunnel 必須前置 **HTTP 401 Passcode Gate**；快照腳本自動遮蔽含 Token/URL Query 的敏感字串 |

---

## 快速開始（Quickstart）

### 方式 A：交給你的 AI Agent 自動巡檢與互動調校（推薦 AX 流程）

在 repo 根目錄下對 Agent 說：

```text
請讀取 @AGENTS.md，先執行 ./ubuntu/scripts/audit-ubuntu.sh 對我的 Linux Dev-Box 進行 100% 唯讀診斷，整理出目前可優化的 DX/AX 項目與預估效益表格，並在取得我同意後逐項幫我套用。
```

### 方式 B：手動執行唯讀環境體檢與 Tmux 快照預覽（100% Safe & Read-Only）

```bash
chmod +x ubuntu/scripts/*.sh

# 1. 執行 100% 唯讀的 Ubuntu / Linux DX × AX 環境診斷
./ubuntu/scripts/audit-ubuntu.sh

# 2. 預覽目前 Tmux 各 Pane 對應的 Agent Session 還原指令（Dry-Run，不寫入檔案）
./ubuntu/scripts/tmux-agent-checkpoint.sh --dry-run
```

---

## 四大韌性模組詳解（4 Pillars of Resilient Agent Dev-Box）

### Pillar 1：Multi-Runtime Tmux Session × JSONL Handoff 精準對映（`OMP` / `AGY` / `Claude` / `Codex`）

#### 背景與挑戰
在同一台 Dev-Box 上，開發者常混合調度四種主流 Agent CLI，甚至在同一個 Tmux Window 下進行 **Cross-Runtime Handoff**（例如 Window 0 跑 `agy` 研究長上下文，Window 1 `OMP-Handoff-*` 跑 `omp` 編排，其他 Panes 跑 `claude` 與 `codex`）。
然而各家 Agent 儲存 Session ID 與狀態的機制完全不同：

| Agent Runtime | 互動式程序特徵 | Session / Conversation ID 解析來源（優先順序） | 精準還原指令格式 | 需過濾的內部 Helper 子程序 |
| :--- | :--- | :--- | :--- | :--- |
| **OMP (`omp`)** | `omp` (Node/Bun runtime) | 1. `/proc/<pid>/cmdline` 中的 `--resume <path_or_id>`<br>2. `/proc/<pid>/fd/*` (或 `lsof`) 實際開啟的 `~/.omp/agent/sessions/<proj>/*.jsonl`<br>3. 對應 CWD 專案目錄下最新修改的 `.jsonl` | `omp --resume <jsonl_path_or_uuid>` | `__omp_worker`、`daemon_broker`、`js_eval`、`text_predict`、`browser-relay` |
| **Google Antigravity (`agy`)** | `agy` | 1. `/proc/<pid>/cmdline` 中的 `--conversation[= ]<uuid>`<br>2. `~/.gemini/antigravity-cli/conversations/*.lock`（或 `/proc/<pid>/fd` 持有的 `<uuid>.db` / presence lock） | `agy --conversation <uuid>` | 背景 subagent worker（非直接綁定於該 Pane TTY 的頂層 CLI） |
| **Claude Code (`claude`)** | `claude` | 1. `/proc/<pid>/cmdline` 中的 `--resume <uuid>` 或 `-r <uuid>`<br>2. `~/.claude/sessions/` 或 PID registry 對應檔<br>3. `~/.claude/projects/<encoded-cwd>/*.jsonl` 最新會話 | `claude --resume <uuid>` | MCP server 子程序 (`node` / `python` / `uvx`) |
| **OpenAI Codex (`codex`)** | `codex` | 1. `/proc/<pid>/cmdline` 中的 `resume <uuid>`<br>2. `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` 開啟之檔案描述子 | `codex resume <uuid>` | Sandbox / command runner 子程序 |

#### 跨視窗 Handoff 命名慣例（`OMP-Handoff-*`）
- 在多 Agent 協作時，建議將同一個專案的跨 Runtime 交接視窗命名為 `OMP-Handoff-<topic>`（例如在 `cc` session 中，`Window 0` 為 `agy`，`Window 1` 為 `OMP-Handoff-cc`，共享相同的 Git Worktree CWD）。
- `./ubuntu/scripts/tmux-agent-checkpoint.sh` 會完整保留 **Session 名稱、Window 順序與名稱、精確的 Window Layout 字串（如 `30ca,113x39,0,0{...}`）、每個 Pane 的 CWD、以及對應的 Agent `--resume` 指令**。

---

### Pillar 2：`boot_id` (`preboot-*`) 防搶佔覆蓋機制與 `flock` 原子寫入

#### 為什麼定時快照會在重開機後「自殺」？
假設你在 Crontab 設定每 15 分鐘執行一次快照寫入 `~/.local/state/ax-playbook/tmux-restores/<host>.sh`。
當雲端主機發生 **Spot Preemption、Host Maintenance Reboot、或 OOM 強制重開機** 時：
1. 系統重開機完成，Crontab 準時觸發。
2. 此時你還沒登入還原 Tmux，或者只剛連進來開了一個空白的 `tmux new -s test`。
3. 沒有 `boot_id` 防護的腳本會直接用這個「空白/殘缺狀態」**覆蓋掉重開機前包含 24 個活躍 Agent 的 `<host>.sh`**！

#### `tmux-agent-checkpoint.sh` 的三道防線
1. **Kernel Boot-ID 狀態機（Linux `/proc/sys/kernel/random/boot_id` / macOS `kern.bootsessionuuid`）**：
   - 每次執行時讀取當前 `BOOT_ID` 並與狀態檔 `<state_dir>/<host>.boot_id` 比對。
   - **一旦發現 `BOOT_ID != LAST_BOOT_ID`**（代表剛經歷過重開機或 VM 搶佔恢復），腳本在寫入任何新資料前，**強制先將上一份 `<host>.sh` 與 `<host>.json` 複製封存為 `preboot-<YYYYMMDD-HHMMSS>.sh` 與 `.json`**。
   - 所有 `preboot-*` 檔案**永久豁免於滾動清理（Rotation Immunity）**，確保無論重開機後過了多久，你永遠找得到重開機前最後一刻的完整 Agent 狀態。
2. **空白 / 低水位防覆蓋保護（`MIN_PANES_GUARD`）**：
   - 若當前 Tmux Server 未運行（0 sessions），腳本直接退出（Exit 0），**絕不覆蓋**既有快照。
   - 若重開機後首次執行時 Pane 數量遠低於重開機前快照，除了已封存 `preboot-*` 外，也會在輸出日誌中明確標記警告。
3. **`flock` 排他鎖與暫存檔原子替換（Atomic Write & Lock Hygiene）**：
   - 內建 `flock -n <lockfile>`（若系統無 `flock` 則自動降級為 atomic `mkdir` lock 並檢查持鎖 PID 是否存活），防止定時任務重疊執行。
   - 若啟用 Git 同步備份，先檢查 `.git/index.lock` 是否為無效孤兒鎖（無存活 `git` 程序持有且逾時 >10 分鐘才提示），並始終透過 `mktemp` 寫入完整檔案並驗證 `bash -n` 語法無誤後，才以 `mv -f` 原子替換目標快照。

#### 操作與排程設定
```bash
# 1. 手動測試預覽（100% 唯讀，印出將生成的還原腳本）
./ubuntu/scripts/tmux-agent-checkpoint.sh --dry-run

# 2. 實際寫入快照（預設存於 ~/.local/state/ax-playbook/tmux-restores/）
./ubuntu/scripts/tmux-agent-checkpoint.sh

# 3. 設定每 15 分鐘自動背景快照（Crontab 範例）
(crontab -l 2>/dev/null; echo "*/15 * * * * $(pwd)/ubuntu/scripts/tmux-agent-checkpoint.sh --quiet") | crontab -
```

---

### Pillar 3：Docker `candidate` 映像檔、Build Cache 與 Git Worktree 磁碟治理

#### 背景與根因
在多 Agent 平行開發的 Dev-Box 上，常見的 CI/CD 與本地驗證模式是：
- 先建置 `<service>:candidate` 映像檔啟動測試容器，驗證通過後再 tag 為 `<service>:stable`。
- 每個子任務獨立建立一個 Git Worktree（例如 `~/workspace/.worktrees/w1-...`、`w2-...`），各自包含 `node_modules` 或 `.venv`。

若缺乏磁碟水位治理，短短幾天內 Docker Overlay2 與 Worktrees 就會將磁碟推升至 **95%+**，引發：
- Agent 無法寫入 `~/.omp/agent/sessions/*.jsonl` 或 `~/.claude/`，導致對話無預警中斷。
- SQLite 狀態庫（如 Antigravity `conversations/*.db`）報 `SQLITE_FULL` 損毀。

#### 安全清理策略（Safety-First Storage Hygiene）
1. **先用 `./ubuntu/scripts/audit-ubuntu.sh` 進行唯讀盤點**：
   - 檢查根目錄與資料分割區的使用率（`>85%` 顯示 `[WARN]`，`>92%` 顯示 `[CRIT]`）與 **Inode 使用率 (`df -i`)**。
   - 統計 Docker Images、Containers、Local Volumes、Build Cache，並特別列出所有 `:candidate` 與 `<none>` (dangling) 映像檔。
   - 盤點 `~/workspace/.worktrees` 下各目錄的大小與最後修改時間。
2. **分級清理原則（須經使用者同意）**：
   - **Level 1（零風險）**：清理 dangling images 與超過 72 小時的未使用 Build Cache：
     ```bash
     docker image prune -f
     docker builder prune --filter "until=72h" -f
     ```
   - **Level 2（保留 `:stable` 與運行中容器，僅移除舊 `:candidate`）**：
     ```bash
     # 列出所有未被運行中容器使用的 :candidate 映像檔供確認
     docker images --format '{{.Repository}}:{{.Tag}} ({{.ID}}) {{.Size}} Created:{{.CreatedSince}}' | grep ':candidate '
     ```
   - **Level 3（已合併之 Git Worktree 歸檔）**：
     ```bash
     git worktree list
     git worktree prune -v
     ```

---

### Pillar 4：外部 Dashboard 與 Tunnel 零信任安全護欄（HTTP 401 Passcode Gate & Zero Secret Exposure）

#### 背景與風險
在 Headless Dev-Box 上，開發者常會啟動各類 Web 介面（例如 Control Center 儀表板、Agent Status Monitor、Vite/Next.js 預覽伺服器），並透過 **Cloudflare Tunnel (`cloudflared`)**、**Tailscale Serve/Funnel** 或 **SSH Reverse Tunnel** 在手機或筆電上檢視。

常見的三大致命失誤：
1. **直接綁定 `0.0.0.0:<port>` 且無雲端防火牆**：任何掃描器都能直接連入開發伺服器或 Agent API。
2. **Cloudflare Quick Tunnel / 公開路由無驗證裸奔**：將本機 Port 直接映射到公開網址，卻未在應用程式或反向代理層加上 **HTTP 401 Passcode Gate**。
3. **命令列與快照機密外洩**：在 Tmux Pane 執行帶有 `--token=...`、`?api_key=...` 或 `Authorization: Bearer ...` 的指令，導致 Tmux `pane_title` 或歷史快照把明文 Token 寫進 Git Repo。

#### 四大安全護欄（Security Guardrails）
1. **Listening Socket 綁定審計**：
   - `./ubuntu/scripts/audit-ubuntu.sh` 會自動透過 `ss -tulpn` 檢查所有非系統標準埠。任何綁定在 `0.0.0.0` 或 `[::]` 的應用層服務（排除 `sshd` 與受控代理）都會觸發警告，建議改綁 `127.0.0.1` 或 Tailscale 介面 IP (`100.x.y.z`)。
2. **強制 HTTP 401 Passcode / Cookie Gate**：
   - 任何透過 `cloudflared` 或反向代理對外提供服務的 Dashboard（如 Agent Control Center），**必須**符合以下兩項之一：
     - 應用層內建 Passcode Gate：未帶有效 Session Cookie 時，所有路由（除 `/login` 與 `/healthz` 外）一律回傳 **`HTTP 401 Unauthorized` 或 `302 Redirect -> /login`**，且 Passcode 比對必須使用 Constant-Time Comparison 並由環境變數注入（嚴禁寫死於程式碼）。
     - 邊界層防護：配置 Cloudflare Access (Zero Trust OTP / OAuth) 或 Nginx Basic Auth。
3. **Tmux 快照自動去敏（Automatic Secret Redaction）**：
   - `./ubuntu/scripts/tmux-agent-checkpoint.sh` 在擷取程序資訊與標題時，**只提取經過白名單驗證的 UUID / `.jsonl` 路徑**，並自動將任何疑似包含 `token=`、`key=`、`secret=`、`password=`、`Bearer ` 或長隨機字串的參數遮蔽為 `[REDACTED]`，確保產出的 `.sh` 與 `.json` 100% 不含任何憑證。
4. **快照目錄權限鎖定 (`chmod 700` / `600`)**：
   - 所有快照與狀態目錄預設以 `umask 077`（目錄 `700`、檔案 `600`）建立，防止同機其他 UID 讀取。

---

## 目錄結構（`ubuntu/` Layout）

```text
ubuntu/
├── README.md                        # Chapter 2: Resilient Agent Dev-Box 完整指南
└── scripts/
    ├── audit-ubuntu.sh              # 100% 唯讀 Ubuntu/Linux DX × AX 環境診斷腳本
    └── tmux-agent-checkpoint.sh     # 跨平台 Tmux × Multi-Agent 快照腳本（含 boot_id preboot 封存、flock、機密遮蔽）
```

---

## License

MIT License — Part of [`jimmyliao/ax-playbook`](../README.md).
