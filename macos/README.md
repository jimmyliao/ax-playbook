# Chapter 1: Lean Agent Mac (`macos/`)

> **Developer eXperience (DX) × Agent eXperience (AX) on Apple Silicon** — 專為 **macOS 26 / 27 (Tahoe, Build `26B123`+)** 與 **Apple Silicon (M1–M4, 16GB+ Unified Memory / 256GB+ SSD)** 打造的系統調校、Chrome 136+ CDP 11.6x 加速、APFS 空間治理、Tmux 重開機自癒與內建 Apple Foundation Models (`fm`) 實戰指南。

[![Platform](https://img.shields.io/badge/macOS-26%20%2F%2027%20(Tahoe)-000000?logo=apple)](#)
[![Architecture](https://img.shields.io/badge/Apple%20Silicon-M1%20%E2%80%93%20M4-blue)](#)
[![Paradigm](https://img.shields.io/badge/Paradigm-DX%20%C3%97%20AX-10b981)](#)
[![Safety](https://img.shields.io/badge/Agent%20Policy-Audit%20First%20%E2%86%92%20Ask%20Consent-amber)](#)

---

## Why Lean Agent Mac?（為什麼 16GB/256GB Mac 需要同時調校 DX 與 AX？）

升級到 **macOS 27** 後，當你在 16GB/32GB Apple Silicon Mac 上同時運行 **日常開發工具（Chrome、IDE、OrbStack、Ghostty/cmux）** 與 **多路常駐 AI Coding Agents（Claude Code、OpenAI Codex、Google Antigravity `agy`、OMP、Playwright/CDP 瀏覽器自動化）**，傳統 dotfiles 只解決了「人類看得到」的設定（DX），卻忽略了「把 Agent 卡死或把系統撐爆」的系統瓶頸（AX）：

| 維度 | 傳統痛點（升級 macOS 27 後常見） | DX × AX 調校後效果（M1 16GB 實測） |
| :--- | :--- | :--- |
| **AX — Agent Browser (Chrome 136+ CDP)** | Chrome 136+ 強制封鎖預設 Profile 的 `--remote-debugging-port`；帶日常 Profile 冷啟動耗時 **5,345 ms**、關閉卡死 **8,002 ms**（SIGTERM timeout） | **雙實例隔離 (`cda` + `chrome-dev-fast`)**：乾淨 Profile 冷啟動 **2,801 ms**、關閉 **92 ms**（快 **87x**）；常駐熱連接僅 **459 ms**（**11.6x 加速**），Dock 獨立翡翠綠 `CDP` 圖示不混淆 |
| **DX + AX — APFS 磁碟與 `code_sign_clone`** | Gatekeeper (`syspolicyd`) 驗證大型 App 逾時殘留 `/private/var/folders/.../X/*.code_sign_clone` 孤兒 bundle，加上雙版本 Framework 與快取吃掉 **18 GB+** | 清除孤兒 `code_sign_clone` (**12.0 GB**)、舊版 Chrome Framework (**745 MB**) 與安全快取 (**5.3 GB**)，並以系統內建 0 額外磁碟的 `fm system` 取代重複本機權重 (**+14.3 GB**) |
| **DX — Spotlight、Menu Bar 與終端機字型** | `mds_stores` 狂掃 `node_modules` / `.git`；13/14 吋瀏海/空間不足吃掉 Menu Bar 圖示；Agent TUI 表格中英混排破版 | **Spotlight 僅索引 Apps + 系統設定**（排除所有開發與快取目錄）；Menu Bar 緊湊間距 (`6/4`) + `Stats.app` + 原生 Swift AI Quota HUD；`Maple Mono NF CN` 完美對齊 Box-drawing |
| **AX — Tmux 跨重開機自癒與 OOM 防護** | macOS 升級重開機後空白 tmux 覆蓋最後快照；子程序 `node` 記憶體暴衝至 >4GB 時，macOS jetsam 因 `get-task-allow` 無法回收導致 **WindowServer 凍結** | **`tmux-agent-checkpoint`** 具備 `kern.bootsessionuuid` 防護與 TTY/Lockfile 精準反查；**`cmux-rss-guard`** 每 30 秒巡檢 >4GB 失控子程序並以 `SIGKILL` 保護 WindowServer |
| **AX — macOS 27 內建 `fm` CLI (AFM 3 Core)** | `/usr/bin/fm` 預設秒退 `exit 69`，模型下載 `97/97` 仍報 `SecureUnableToPersonalize (6535)`，Agent 背景呼叫 `pcc` 報 `HTTP 503` | 完整解鎖 `sudo fm license` 與 Apple TSS 簽章驗證；釐清 `fm respond --model system` (**0.764s TTFT**) 與 `Terminal.app` 專屬 PCC 權限邊界 |

---

## 快速開始（Quickstart）

### 方式 A：交給你的 AI Agent 自動巡檢與互動調校（推薦 AX 流程）

在 repo 根目錄下對 Agent 說：

```text
請讀取 @AGENTS.md，先執行 ./macos/scripts/audit-macos.sh 對我的 Mac 進行 100% 唯讀診斷，整理出目前可優化的 DX/AX 項目與預估效益表格，並在取得我同意後逐項幫我套用。
```

> [!IMPORTANT]
> [`../AGENTS.md`](../AGENTS.md) 內建嚴格的 **三階段安全契約（Audit First → Explain Impact → Explicit User Consent）**。未經你明確授權，Agent 絕不會擅自刪除快取、修改 `defaults` 或終止瀏覽器。

### 方式 B：手動執行唯讀環境體檢（100% Safe & Read-Only）

```bash
chmod +x macos/scripts/*.sh
./macos/scripts/audit-macos.sh
```

此腳本**不會修改任何檔案或設定**，會在 3 秒內檢查你的：
- macOS 版本、記憶體壓力 (`vm_stat` / `swapusage`) 與 APFS 可用空間
- Chrome / Chrome Dev 預設 Profile 肥大程度、Port `9222` CDP 狀態、舊版 Framework 殘留與 `/private/var/folders` 下的 `code_sign_clone` 孤兒容量
- Spotlight 索引設定與開發目錄排除狀態
- Menu Bar 間距設定 (`NSStatusItemSpacing`) 與 Ghostty / `cmux` 字型設定
- `tmux` 存活狀態與 LaunchAgents 守護腳本（`cmux-rss-guard`、`ram-watch`、`omp-tmux-checkpoint`、Keystone updater）
- macOS 27 `/usr/bin/fm` (Apple Foundation Models) 授權與就緒狀態

---

## 五大調校模組詳解（5 Pillars of macOS 27 DX × AX Tuning）

### Pillar 1：Chrome 136+ CDP 雙實例隔離與 11.6x 啟動加速（AX + DX）

#### 背景與根因
1. **Chrome 136+ 安全性變更**：自 Chrome 136 起，基於防止惡意程式竊取日常 Cookie 的安全策略，當 `--user-data-dir` 指向預設目錄（`~/Library/Application Support/Google/Chrome` 或 `Chrome Dev`）時，Chrome 會**強制忽略或拒絕 `--remote-debugging-port`**。
2. **肥大日常 Profile 拖垮 Agent 自動化**：日常開發 Profile 動輒累積數 GB 的 `Service Worker`、10+ 個擴充功能與數十個歷史分頁，導致 Agent 每次啟動/關閉瀏覽器耗時 **5.3 秒 / 8.0 秒**。

#### 實測數據（Apple M1 16GB, Chrome Dev `159.0.8144.0`）

| 指標 | 調校前（日常肥大 Profile） | 調校後（`chrome-dev-fast` 獨立 Profile） | 常駐熱實例（`cda` Port `9222`） | 提升幅度 |
| :--- | :---: | :---: | :---: | :---: |
| **冷啟動 + CDP Port Ready** | `5,345 ms` | `2,801 ms` (Headless: `2,076 ms`) | **`459 ms`** (直接 Attach) | **11.6x 加速** |
| **優雅關閉耗時 (`SIGTERM`)** | `8,002 ms` (逾時強殺) | **`92 ms`** | 免關閉（常駐背景複用） | **87x 加速** |
| **Dock / `Cmd+Tab` 辨識度** | 兩個相同藍圖示極易誤關 | 翡翠綠 **`CDP`** 專屬圖示 + 視窗前綴 `🟢 [CDP Agent]` | 獨立 `.app` Bundle 隔離 | **零誤判** |

#### 解決方案與工具 (`./macos/scripts/tune-chrome-cdp.sh`)
- **雙軌架構**：
  1. **日常個人瀏覽器 (`Google Chrome Dev.app`)**：保留完整擴充功能、書籤、Google 同步與 Apple Keychain。
  2. **CDP Agent 專屬瀏覽器 (`Chrome Dev (CDP Agent).app` / `cda` / `chrome-dev-fast`)**：
     - 綁定獨立輕量 `--user-data-dir`（如 `~/.omp/browser-profiles/chrome-cdp-agent` 或 `~/.cache/chrome-dev-fast`）
     - 固定開啟 `--remote-debugging-port=9222`
     - 注入減重與無干擾 Flags：
       ```text
       --no-first-run --no-default-browser-check
       --disable-background-networking --disable-component-update
       --disable-sync --disable-default-apps --metrics-recording-only
       --disable-domain-reliability --disable-breakpad --disable-client-side-phishing-detection
       --disable-features=Translate,OptimizationHints,MediaRouter,OptimizationGuideModelDownloading,OnDeviceModelService
       --password-store=basic --use-mock-keychain
       ```
     - **macOS Headless 修復**：在 `--headless` 模式下自動加上 `--headless=new --disable-gpu`，消除 macOS 特有的 `CVDisplayLinkCreateWithCGDisplay failed (-6670)` 錯誤與 GPU process 初始化延遲。
- **操作指令**：
  ```bash
  # 1. 唯讀檢查 Chrome 快取、舊版 Framework 與 code_sign_clone 佔用
  ./macos/scripts/tune-chrome-cdp.sh audit

  # 2. 啟動/Attach 速度極快的隔離 CDP 瀏覽器（Port 9222）
  ./macos/scripts/tune-chrome-cdp.sh launch

  # 3. 建立獨立 Dock 圖示的 /Applications/Chrome Dev (CDP Agent).app
  ./macos/scripts/tune-chrome-cdp.sh install-wrapper
  ```

---

### Pillar 2：APFS `code_sign_clone` 幽靈空間回收與磁碟治理（Storage Hygiene）

#### 背景與根因
在 macOS 26/27 上，我們在 M1 16GB 主機發現高達 **18 GB+** 的隱形空間流失，主要來自三個罕為人知的機制：

1. **Gatekeeper `code_sign_clone` 孤兒快照（實測佔用 `12.0 GB`）**：
   - 當 `Google Chrome Dev.app`（單一 Bundle 達 1.5 GB）在背景更新或多次同時啟動時，macOS `syspolicyd` 會在 `/private/var/folders/<xx>/<yy>/X/com.google.Chrome.dev.code_sign_clone/code_sign_clone.<UUID>/` 下建立 APFS Copy-on-Write 驗證副本。
   - 若驗證逾時或被中斷，這些 `.bundle` 目錄會成為孤兒，8 個殘留副本就顯示佔用 **12 GB**。
2. **Chrome Framework 雙版本並存（實測佔用 `745 MB`）**：
   - `Google Chrome Dev.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/` 常同時保留上一版與 `Current` 版本，使整個 `.app` 膨脹一倍。
3. **Chrome `Service Worker` 與 GPU 快取暴增（實測佔用 `5.3 GB`）**：
   - 日常 Profile 的 `Service Worker/CacheStorage` 單一目錄可膨脹至 **2.1 GB+**，加上 `component_crx_cache` (`466 MB`) 與 `~/Library/Caches/Google/Chrome Dev` (`1.6 GB`)。
   - **安全清理原則**：清理 `Service Worker`、`GPUCache`、`DawnGraphiteCache`、`DawnWebGPUCache`、`ShaderCache`、`GrShaderCache`、`component_crx_cache` **完全不會影響**書籤 (`Bookmarks`)、密碼 (`Login Data`)、已登入狀態 (`Cookies`) 與歷史紀錄 (`History`)。
4. **macOS 27 系統升級後殘留與模型整併（實測回收 `+15 GB`）**：
   - 升級 macOS 27.2 後，`/System/Volumes/Data/macOS Install Data` 可能殘留 `2.8 GB` 安裝檔；`/System/Library/AssetsV2` 佔約 `17 GB`（含 Apple Intelligence AFM 系統資產 `~6.5 GB` 與 Xcode iOS Simulator Runtime `8.5 GB`）。
   - 由於 macOS 27 內建 `fm --model system` 已預載於系統卷宗（**0 額外磁碟成本**），可安全移除 `~/.cache/huggingface/hub` 中重複的 3B~4B 實驗模型權重（實測回收 **14.3 GB**）。

#### 操作指令
```bash
# 預覽可安全回收的 code_sign_clone、舊版 Framework 與 Chrome 快取（Dry-Run，不刪除）
./macos/scripts/tune-chrome-cdp.sh clean --dry-run

# 確認無誤後執行清理（不會觸碰 Bookmarks / Cookies / Login Data）
./macos/scripts/tune-chrome-cdp.sh clean --apply
```

---

### Pillar 3：System UI、Spotlight 開發者降噪、Menu Bar 與終端機字型（DX）

#### 1. Spotlight 僅索引「應用程式与系統設定」（消除 `mds_stores` 狂飆）
開發者與 AI Agent 頻繁建立 worktree、`node_modules`、`.venv`、Docker layer 與大量 log，會讓 macOS Spotlight (`mds_stores` / `spotlightknowledged`) 持續佔用 CPU 與 SSD I/O。
- **策略**：
  - 將 `com.apple.Spotlight orderedItems` 中除了 `APPLICATIONS` 與 `SYSTEM_PREFS` 以外的 19 個分類（文件、資料夾、PDF、訊息、圖片、Siri 建議等）全部設為 `enabled = 0`。
  - 在高頻讀寫開發目錄（`~/workspace`、`~/.cache`、`~/.npm`、`~/.nvm`、`~/.cargo`、`~/.gradle`、`~/.docker`、`~/.orbstack`、`~/.ollama`、`~/Library/Caches`）放置 `.metadata_never_index` 並寫入 Spotlight `VolumeConfiguration.plist` `Exclusions`。

#### 2. Menu Bar 緊湊間距與狀態監控 HUD
MacBook Air / Pro 13~14 吋螢幕的 Menu Bar 極易因圖示間距過寬而被裁切隱藏：
```bash
# 縮小 Menu Bar 圖示間距與內距（預設約 16/12 -> 調校為 6/4）
defaults -currentHost write -globalDomain NSStatusItemSpacing -int 6
defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 4
killall ControlCenter
```
- **硬體監控**：使用開源輕量的 **`Stats.app`** (`brew install --cask stats`)，並開啟 `CombinedModules = 1` 將 CPU / RAM / 溫度合併為單一緊湊指標。
- **AI Agent 額度監控 (`LeapEdge.app`)**：以原生 Swift 撰寫常駐 Menu Bar App，即時顯示多供應商（AGY、Claude、Codex、Grok、Copilot）5H/7D Quota 與 Reset 倒數；Popover 關閉時自動釋放 `WKWebView`（背景常駐僅 **~12 MB RAM**）。

#### 3. Ghostty / `cmux` 終端機字型對齊（`Maple Mono NF CN`）
AI Agent CLI（Claude Code、Codex、OMP、AGY）大量使用 Unicode Box-drawing 字元（`╭─╮│╰─╯`）搭配繁體中文輸出。
- 安裝 **`Maple Mono NF CN`** (`brew install --cask font-maple-mono-nf-cn`) 並在 `~/.config/ghostty/config` 設定：
  ```ini
  font-family = Maple Mono NF CN
  font-size = 14
  font-thicken = true
  ```
  解決中英混排寬度非嚴格 2:1 造成的表格右邊框歪斜問題，同時在 Retina 螢幕呈現飽滿字重。

---

### Pillar 4：AI Agent Runtime、Tmux 跨重開機自癒與 16GB OOM 護欄（AX）

在 16GB Unified Memory 的 Mac 上同時跑多個 Agent Session，最大的風險是 **1) 子程序記憶體洩漏拖垮 WindowServer**，以及 **2) 系統重開機後所有 Tmux 工作區與 Agent Session ID 遺失**。

#### 1. `cmux-rss-guard` — 防止 Hardened Runtime 子程序凍死 WindowServer
- **根因**：macOS Kernel Jetsam 在記憶體耗盡時，對於帶有 `com.apple.security.get-task-allow`（常見於開發版終端機如 `cmux` 及其衍生 `node` 子程序）的 프로세스回收遲緩。一旦某個 runaway `node` / MCP server 暴衝超過 4GB RSS，WindowServer 會先失去回應導致整台 Mac 假死。
- **解法**：透過 LaunchAgent 每 30 秒執行 `cmux-rss-guard.sh`，沿 `ppid` 樹巡檢終端機旗下的 `node` 子程序；若單一程序 `RSS > 4 GB (4,194,304 KB)`，直接發送 POSIX `SIGKILL` (`kill -9`) 秒殺該失控子程序，保全主會話與系統 UI。

#### 2. `omp-tmux-checkpoint` + `m1-boot-restore` — 跨重開機精準還原
- **Host 隔離與防漂移**：使用 `scutil --get LocalHostName`（而非會隨 DHCP 改變的 `hostname -s`）作為快照命名空間。
- **Boot-ID 防覆蓋保護 (`kern.bootsessionuuid`)**：每 15 分鐘快照時比對 `sysctl -n kern.bootsessionuuid`。一旦偵測到剛重開機，先將上一份重開機前的健康快照封存為 `preboot-<timestamp>.sh`（永久豁免於滾動刪除），徹底杜絕「重開機後空白 tmux 把重開機前快照蓋掉」的慘劇。
- **TTY + Lockfile 雙向反查**：自動解析每個 tmux pane 內正在跑的是 `omp`、`agy`、`claude` 或 `codex`，並產生包含正確 `cd <cwd>` 與 `--resume <session-id>` 的可執行還原腳本。
- **開機延遲等待 (`boot-restore.sh`)**：登入後先等待 45 秒讓網路與基礎服務就緒，並輪詢等待 **OrbStack Docker Socket (`~/.orbstack/run/docker.sock`)** 達 90 秒後才執行 tmux 還原，確保依賴容器的開發環境一次到位。

#### 3. `ram-watch` — 15 秒級輕量記憶體黑盒子
- 每 15 秒採樣 `vm_stat`（free / active / wired / compressed）與 `sysctl vm.swapusage` 及 Top 3 RSS 程序寫入單行日誌，滿 100 MB 自動 `gzip` 輪替；當累積超過 2 GB 且超過 30 天時僅發送 **macOS 原生通知提醒**，絕不擅自刪除歷史診斷證據。

---

### Pillar 5：macOS 27 內建 Apple Foundation Models (`fm` CLI) 解鎖與實戰邊界（AX）

macOS 27 新增了官方 `/usr/bin/fm` CLI，可直接呼叫系統內建的 **Apple Foundation Models (AFM 3 Core, ~3B)** 與 **Private Cloud Compute (`pcc`)**，完全不佔用額外磁碟空間，非常適合擔任本機分類、摘要、Git commit 訊息生成與輕量路由。

#### 三大必踩坑與解法

| 現象 / 錯誤碼 | 根本原因 | 解決方法 |
| :--- | :--- | :--- |
| 執行任何 `fm` 指令（含 `fm --help`）直接回傳 **`exit code 69` (`EX_UNAVAILABLE`)** | 尚未在互動式終端機簽署 Apple Foundation Models 使用條款 | 在原生終端機執行 `sudo fm license`，輸入 `q` 並輸入 `agree` 完成系統級授權 |
| 模型下載進度達 `97/97`，但 `fm respond` 報 **`SecureUnableToPersonalize (6535)`** | Siri 語系未設為 `English (United States)`，或 `generativeexperiencesd` 向 `https://gsra.apple.com:443/TSS/controller?action=2` 請求加密個人化簽章 (`Ap,SystemVolumeCanonicalMetadata`) 尚未完成 | 1. 確認「系統設定 → Apple Intelligence & Siri」語系為 `English (US)`<br>2. 重新開關一次 Apple Intelligence 觸發 TSS 簽章重試<br>3. 執行 `fm models` 確認顯示 `✓ system (AFM 3 Core)` |
| 透過 `fm serve` 呼叫 `"model": "pcc"` 時回傳 **`HTTP 503 ("Please use the Terminal app")`** | Apple 對 Private Cloud Compute (`pcc`) 設有嚴格的 TCC / Entitlement 來源檢查，阻擋第三方終端機 (`cmux`) 或背景 Agent 子程序直接發起 PCC 請求 | - **背景 Agent / 腳本**：一律指定 `--model system`（100% On-Device，M1 實測中位數 **TTFT `0.764s` / Total `0.968s`**）<br>- **若需呼叫 `pcc`**：必須從 macOS 原生 **`Terminal.app`** 啟動 `fm serve --host 127.0.0.1 --port 19761`（實測 `HTTP 200`，耗時 `1.09s`） |

#### 本機小模型定位建議（M1 16GB 實測基準）
- **`/usr/bin/fm --model system` (AFM 3 Core)**：**0 GB 額外磁碟**、隨叫隨到、TTFT `0.76s` → 適合**系統通知摘要、日誌分類、短文本改寫**。
- **`llama.cpp` / `Ollama` (`Gemma 4 E2B` / `Qwen3 4B`)**：TTFT **`0.15s`**、約 `25~30 tok/s` → 適合**高頻低延遲 JSON 結構化擷取、多語翻譯**。
- **`whisper.cpp` (`ggml-breeze-asr-26-q4_0.bin`, `848 MB`)**：針對台灣繁體中文與中英夾雜語音微調，單一檔案即可離線高速轉錄。

---

## 目錄結構（`macos/` Layout）

```text
macos/
├── README.md                    # Chapter 1: Lean Agent Mac 五大模組詳解與實測數據
└── scripts/
    ├── audit-macos.sh           # 100% 唯讀系統與 Agent 環境健檢腳本
    └── tune-chrome-cdp.sh       # Chrome 136+ CDP 雙實例啟動器、App Wrapper 生成與安全快取清理工具
```

---

## License

MIT License — Part of [`jimmyliao/ax-playbook`](../README.md).
