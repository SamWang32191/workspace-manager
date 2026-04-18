# Workspace Symlink Manager 設計

## 背景

目前 `/Users/samwang/tmp/Workspace` 下有三個 workspace：

- `Iris/`
- `scins-asi-cie/`
- `TransGlobe/`

每個 workspace 內都有：

- 一份相同的 `link-repos.sh`
- 一份不同內容、但用途一致的 `repo-list.txt`

這造成兩個主要問題：

1. 腳本重複，修改或修正時需要同步多份。
2. repo 清單分散在各 workspace，不利於集中管理與重用。

## 目標

建立一套集中管理的 workspace 建立與 symlink 同步流程，滿足以下需求：

- 使用單一 CLI 指令建立新 workspace
- 將 repo 清單集中管理
- 允許 workspace 名稱與 profile 名稱分離
- 保持 symlink 建立流程安全、不強制覆蓋既有真實檔案或資料夾
- 讓既有 workspace 可逐步遷移，不必一次全面替換
- 避免讓中央設定檔混入動態 workspace 狀態

## 選定方案

採用「宣告式設定檔 + CLI」方案，但將責任拆成：

- 中央設定檔只管理靜態 `profiles`
- 每個 workspace 本地只管理自己使用的 profile 名稱

核心做法：

- 提供一個全域 CLI，例如 `workspace`
- 使用一份集中設定檔，例如 `~/.config/workspace-manager/workspaces.yaml`
- 在設定檔中宣告：
  - repo 基底路徑
  - workspace 根目錄
  - 多個 profiles
- 由 CLI 統一負責建立目錄、建立 symlink、重新同步與狀態檢查
- 由每個 workspace 的本地 metadata 檔記錄「自己使用哪個 profile」

每個 workspace 本身不再保留 `link-repos.sh` 與 `repo-list.txt`，只保留極小的 metadata 檔。

## 架構

### 1. 全域 CLI

CLI 是唯一入口，負責：

- 讀取設定檔
- 驗證輸入參數
- 建立 workspace 目錄
- 依 profile 建立或更新 symlink
- 顯示狀態與診斷資訊

### 2. 集中設定檔

設定檔使用 YAML，以可讀性與手動維護便利性為優先。

建議位置：

`~/.config/workspace-manager/workspaces.yaml`

建議結構：

```yaml
base_repo_dir: /Users/samwang/code/github.com/softleader
workspace_root: /Users/samwang/tmp/Workspace

profiles:
  iris:
    - iris-admin-ui
    - iris-auth
    - iris-finance
  transglobe:
    - kapok-auth
    - kapok-auth-ui
  scins-asi-cie:
    - scins-asi-auth
    - scins-asi-frontend-cie
```

這份設定檔不記錄任何已建立的 workspace 狀態，避免中央檔案同時承擔「靜態設定」與「動態狀態」兩種責任。

### 3. Workspace 本地 metadata

每個 workspace 建立後，會在其根目錄寫入一個單行文字檔：

`.workspace-profile`

內容只包含 profile 名稱，例如：

```text
iris
```

這個檔案只負責一件事：讓 CLI 知道此 workspace 對應哪個 profile。

不使用 JSON 或 YAML，因為第一版沒有額外 metadata 需求，使用單行文字檔最輕量。

### 4. Profile 與 Workspace 分離

- `profile` 代表 repo 組合模板
- `workspace name` 代表實際工作目錄名稱

例如：

- `workspace create ticket-123 --profile iris`

會建立：

- `/Users/samwang/tmp/Workspace/ticket-123`

並在其中建立 `iris` profile 內所有 repo 的 symlink，並寫入 `.workspace-profile`。

## CLI 介面

第一版先提供最小且足夠的命令集合：

### `workspace create <name> --profile <profile>`

用途：

- 建立新的 workspace 目錄
- 根據 profile 建立 symlink
- 寫入 `.workspace-profile`

若目標目錄已存在：

- 若目錄內已有 `.workspace-profile`，提示這是既有 workspace，應改用 `sync`
- 若目錄內沒有 `.workspace-profile`，拒絕接手，避免誤操作普通資料夾

### `workspace sync <path>`

用途：

- 讀取 `<path>/.workspace-profile`
- 重新套用 profile 中定義的 repo 清單
- 補齊遺漏 symlink
- 修正錯誤 symlink

第一版不要求用 workspace 名稱反查中央設定，也不回寫中央 YAML。

### `workspace list-profiles`

用途：

- 列出所有可用 profiles

### `workspace show <path>`

用途：

- 顯示 workspace 的實體路徑
- 顯示使用中的 profile
- 顯示 profile 內定義的 repo 清單

### `workspace doctor <path>`

用途：

- 檢查缺少的 source repo
- 檢查壞掉或指向錯誤位置的 symlink
- 檢查設定檔與實際目錄是否不一致

## 同步規則

`create` 與 `sync` 共用同一套處理規則：

1. 若 source repo 不存在，列為 warning，整體流程不中止。
2. 若目標路徑不存在，建立 symlink。
3. 若目標已是正確 symlink，保留不動。
4. 若目標是錯誤 symlink，更新為正確來源。
5. 若目標是一般檔案或一般資料夾，跳過並輸出警告，不強制覆蓋。
6. 若 workspace 內存在 profile 清單以外的額外 symlink，第一版不主動刪除。

這套規則延續目前 `link-repos.sh` 的安全特性，但把行為集中到單一工具中。

若未來需要強一致模式，再新增 `--prune` 選項，而不是在第一版預設刪除額外 symlink。

## 資料流

### 建立 workspace

1. 使用者執行 `workspace create <name> --profile <profile>`
2. CLI 讀取 YAML 設定檔
3. 驗證 `profile` 是否存在
4. 建立 workspace 目錄（若尚未存在）
5. 在 workspace 根目錄寫入 `.workspace-profile`
6. 依據 profile 列表逐一建立或更新 symlink
7. 輸出建立結果與警告

### 同步 workspace

1. 使用者執行 `workspace sync <path>`
2. CLI 從 `<path>/.workspace-profile` 讀出對應 profile
3. 套用同步規則更新 symlink
4. 輸出保留、更新、建立、跳過、warning 的摘要

## 錯誤處理

需明確處理下列情境：

- 設定檔不存在
- 設定檔 YAML 格式錯誤
- 指定的 profile 不存在
- `base_repo_dir` 或 `workspace_root` 不存在
- `.workspace-profile` 不存在
- `.workspace-profile` 指向不存在的 profile
- source repo 缺失
- 目標位置已有非 symlink 項目

原則：

- 設定層級錯誤直接失敗並結束
- workspace metadata 缺失或不合法時直接失敗並提示修正
- 個別 repo 層級錯誤以 warning 回報，保留其他 repo 的處理結果

## 遷移策略

採漸進式遷移：

1. 將現有三份 `repo-list.txt` 轉為 YAML `profiles`
2. 保留舊 `link-repos.sh` 一段過渡期，僅供既有流程使用
3. 新建立的 workspace 全改用 `workspace create`
4. 既有 workspace 需要切換時，只要補上一個 `.workspace-profile` 即可改走 `workspace sync <path>`
5. profile 內容仍由手動編輯中央 YAML 維護，第一版不做 profile CRUD 指令
6. 確認新流程穩定後，移除舊腳本與分散式清單

## 驗證與測試

至少驗證以下情境：

- profile 解析正確
- `.workspace-profile` 讀取正確
- workspace 目錄建立成功
- 正確 symlink 會被保留
- 錯誤 symlink 會被更新
- 缺少 source repo 時會產生 warning
- 既有一般檔案或資料夾不會被覆蓋
- 額外 symlink 不會被 `sync` 自動刪除
- 已存在但不是 workspace 的目錄不會被 `create` 接手

## 非目標

第一版不包含以下能力：

- 自動從命名規則掃描 repo 產生 profile
- 互動式 TUI 選單
- profile CRUD 管理命令
- 自動刪除 profile 中已不存在的多餘目標項目
- 多組 base repo roots 或跨 owner repo 搜尋

## 推薦原因

相較於只集中一份 shell script 或只集中 `repo-list.txt`：

- 宣告式設定更容易維護與擴充
- workspace 與 profile 分離，更符合實際使用情境
- 中央 profiles + 本地 `.workspace-profile` 的責任邊界清楚，不必在中央 YAML 回寫動態狀態
- 指令更穩定，未來加上 `rename`、`clone-check`、`export`、`--prune` 等功能時也有清楚的演進方向
- 對目前需求而言仍保持輕量，不需要導入過度複雜的系統
