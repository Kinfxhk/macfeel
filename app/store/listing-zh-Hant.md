# App Store listing — macfeel 1.0.0

App Store Connect 貼上用的稿。語言：繁體中文（主語言）／English（第二語言，可後加）。

## 基本資料

| 欄位 | 值 |
|---|---|
| 名稱（30 字內） | macfeel |
| 副標題（30 字內） | 讓 macOS 具備 Linux 的手感 |
| Bundle ID | com.kinfxhk.macfeel |
| SKU | macfeel-1 |
| 版本 | 1.0.0（build 1） |
| 類別 | 工具程式（public.app-category.utilities） |
| 價格 | 免費 |
| 版權 | © 2026 KinFx |
| 年齡分級 | 4+ |
| 私隱政策 URL | https://kinfxhk.github.io/macfeel/privacy.html |
| 支援 URL | https://kinfxhk.github.io/macfeel/support.html |
| 營銷 URL（可選） | https://kinfxhk.github.io/macfeel/ |

## 描述（zh-Hant）

> macOS 的介面預設是給一般使用者調的：慢動畫、長按彈字、黏住的 Dock。
> macfeel 把這些一次改到順手，而且每一項都寫明它在改哪個 `defaults` 鍵。

**它會改什麼**

- 速度：關窗／開窗動畫、視窗縮放、Dock 出現時間、Mission Control 動畫
- Dock：自動隱藏、即時彈出、用 scale 代替 genie、隱藏最近使用
- Finder：顯示副檔名、路徑列、狀態列、完整路徑、資料夾排先、唔寫 .DS_Store
- 鍵盤：按鍵重複速度、關長按選字、關智能引號與自動修正
- 截圖：PNG、固定資料夾、無陰影、無縮圖
- 觸控板與滑鼠：關自然捲動、關滑鼠加速、輕點即按

**三個累積組合**：輕量 15 項、標準 38 項、硬核 47 項。套用前會先列出完整改動清單，
確認後才寫入。

**可以還原**：每次套用前自動建立快照；「還原」回到第一次執行之前，「還原此項」刪除單一鍵值
回到 macOS 預設。

**不需要權限**：不要求「輔助使用」，不修改 SIP，不安裝核心擴充，沒有網絡功能，不收集任何資料。

部分設定要重開 app 或登出才生效，每一列右邊的 ⓘ 會寫明。

## 關鍵字（100 字元內）

```
defaults,macOS,調校,Dock,Finder,鍵盤,動畫,截圖,終端機,開發者,Linux,手感,工具
```

## 截圖（1280×800）

1. `docs/store/01-panel-dark-1280x800.png` — 主面板（深色）
2. `docs/store/02-panel-light-1280x800.png` — 主面板（淺色）

## App Review 備註（要填在 App Review Information）

> macfeel 只寫入使用者層級的偏好設定（`~/Library/Preferences`），使用的 entitlement 是
> `com.apple.security.temporary-exception.shared-preference.read-write`，範圍限於
> `com.apple.dock`、`com.apple.finder`、`com.apple.screencapture`、
> `com.apple.AppleMultitouchTrackpad` 與 `kCFPreferencesAnyApplication`（全域設定）。
> 沙盒沒有公開 API 可以修改其他 app 的偏好設定，所以必須用這個 exception；
> 每一項改動都可以由使用者按「還原」復原，不改 SIP、不需要輔助使用權限。
>
> 沙盒版不能代使用者重啟 Dock／Finder，app 會提示使用者登出或重開 app。

## English (secondary locale)

Name: macfeel · Subtitle: Make macOS feel like Linux

> macfeel changes the macOS defaults that make the interface feel slow: window
> animations, Dock timing, key repeat, Finder columns, screenshot location.
> Every row names the `defaults` key it writes, the change list is shown before
> anything is written, and a snapshot makes every change reversible.
> No Accessibility permission, no SIP changes, no network, no data collection.
