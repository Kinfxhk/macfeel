#!/usr/bin/env python3
"""Generate lib/i18n/*.tsv from the zh-Hant source plus the translations below.

Run once; the TSVs are the source of truth afterwards (this script is kept so a new
language is one dict away, but CI validates the TSVs, not this file).
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
I18N = ROOT / "lib" / "i18n"
I18N.mkdir(parents=True, exist_ok=True)


def read_tsv(path):
    out = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) >= 2:
            out[parts[0]] = parts[1]
    return out


# --- per-tweak text: en + zh-Hans (zh-Hant already lives in tweaks.conf / notes.conf) --------
DESC = {
 "win.corner": ("Window corner radius — 0.1 is square, 4 Catalina, 9 Sequoia, 16 Tahoe's default.",
                "窗口圆角 — 0.1 是直角，4 等于 Catalina，9 等于 Sequoia，16 是 Tahoe 预设。"),
 "win.sidebar-float": ("Sidebar sits flush with the window edge instead of floating as a card.",
                       "侧边栏贴住窗口边，不再浮起成卡片。"),
 "win.sidebar-radius": ("Corner radius of the glass sidebar (Finder, Mail, Notes).",
                        "玻璃侧边栏的圆角（Finder、邮件、备忘录）。"),
 "win.no-animations": ("No open/close window animation — apps appear instantly.",
                       "关掉开窗／关窗动画，app 即刻出现。"),
 "win.resize-time": ("Window resize animation length; 0.001 s feels immediate.",
                     "窗口缩放动画时长，0.001 秒等于即时。"),
 "win.save-expanded": ("Save/Open panels default to the expanded form (type a path).",
                       "保存／打开面板默认用展开版（可以输入路径）。"),
 "win.save-expanded2": ("Same, for the newer AppKit key.",
                        "同上，给新版 AppKit 用。"),
 "win.tableView-compact": ("Smaller list rows — more items visible at once.",
                           "列表行距收窄，一次看到更多项。"),
 "win.dblclick-maximize": ("Double-clicking a title bar maximises instead of minimising.",
                           "双击标题栏＝放到最大，不再是缩到 Dock。"),
 "win.quicklook-instant": ("Quick Look opens with no zoom animation.",
                           "空白键预览不再有放大动画。"),
 "kbd.repeat": ("Key repeat at the fastest setting.",
                "按键重复速度调到最快。"),
 "kbd.repeat-initial": ("Shorter delay before a held key starts repeating.",
                        "按住键后更快开始重复。"),
 "kbd.no-hold-popup": ("Holding a key repeats it instead of offering accented characters.",
                       "长按＝重复字符，不再弹音标候选。"),
 "kbd.no-smart-quotes": ("Straight quotes stay straight — no “smart” quotes in code.",
                         "直引号保持原样，写代码不会被改成弯引号。"),
 "kbd.no-smart-dashes": ("-- stays -- instead of becoming an en dash.",
                         "-- 不会被自动改成破折号。"),
 "kbd.no-autocorrect": ("Spelling is not corrected while you type.",
                        "关闭自动拼写修正。"),
 "kbd.no-autocapitalize": ("No automatic capitalisation at sentence starts.",
                           "关闭自动大写。"),
 "kbd.no-text-completion": ("No inline predictive text covering what you type.",
                            "关闭行内预测文字。"),
 "kbd.full-keyboard-access": ("Tab reaches every control, not just text fields.",
                              "Tab 可以 focus 所有控件，不只是文字框。"),
 "dock.autohide": ("Dock hides when unused.",
                   "Dock 自动隐藏。"),
 "dock.autohide-delay": ("Dock appears the moment the pointer hits the bottom edge.",
                         "鼠标推到底部即刻弹出 Dock。"),
 "dock.autohide-time": ("Faster Dock show/hide animation.",
                        "Dock 出现／收起动画更快。"),
 "dock.mineffect": ("Windows scale into the Dock instead of the genie effect.",
                    "窗口缩到 Dock 用 scale，不用 genie。"),
 "dock.no-recents": ("No recent-apps section in the Dock.",
                     "Dock 不再显示最近使用的 app。"),
 "dock.expose-speed": ("Mission Control animation cut to 0.1 s.",
                       "Mission Control 动画缩短到 0.1 秒。"),
 "dock.no-launch-anim": ("No bounce when an app launches.",
                         "开 app 时 Dock 图标不再弹跳。"),
 "spaces.fixed-order": ("Spaces keep a fixed order instead of re-sorting by recent use.",
                        "Space 固定顺序，不再按最近使用重排。"),
 "finder.extensions": ("Show file extensions everywhere.",
                       "所有文件显示扩展名。"),
 "finder.pathbar": ("Path bar at the bottom of Finder windows.",
                    "Finder 窗口底部显示路径列。"),
 "finder.statusbar": ("Status bar with item count and free space.",
                      "显示项目数和可用空间。"),
 "finder.fullpath": ("Full path in the Finder title bar.",
                     "Finder 标题栏显示完整路径。"),
 "finder.folders-first": ("Folders sort before files.",
                          "排序时文件夹排前面。"),
 "finder.no-ext-warning": ("No warning when changing a file extension.",
                           "改扩展名不再弹警告。"),
 "finder.no-ds-network": ("No .DS_Store on network volumes.",
                          "网络卷不写 .DS_Store。"),
 "finder.no-ds-usb": ("No .DS_Store on USB volumes.",
                      "USB 不写 .DS_Store。"),
 "shot.no-shadow": ("Screenshots without the window shadow.",
                    "截图不带窗口阴影。"),
 "shot.format": ("Screenshots saved as PNG.",
                 "截图保存为 PNG。"),
 "shot.location": ("Screenshots go to ~/Pictures/Screenshots.",
                   "截图统一存到 ~/Pictures/Screenshots。"),
 "shot.no-thumbnail": ("No floating thumbnail after a screenshot.",
                       "截图后不再弹缩略图。"),
 "ptr.natural-scroll": ("Scrolling follows the Linux/Windows direction.",
                        "滚动方向跟 Linux／Windows 一致。"),
 "ptr.linear-mouse": ("Mouse acceleration off — needs a logout; the tracking slider resets it.",
                      "关闭鼠标加速 — 需要注销；一拉追踪速度滑杆就会被重置。"),
 "ptr.tap-to-click": ("Tap the trackpad to click.",
                      "触控板轻点即当左键。"),
 "menubar.hide-fullscreen": ("No menu bar in full-screen apps.",
                             "全屏时不显示菜单栏。"),
 "chrome.hide-menubar": ("Menu bar auto-hides; move the pointer up to reveal it.",
                         "菜单栏自动隐藏，鼠标推上去才出现。"),
}

NOTE = {
 "win.corner": ("The radius the WindowServer gives every standard window. 0.1 is a hard right angle; values above ~20 start to look like a pill. Apps have to be relaunched to pick it up, and apps that draw their own chrome (games, some Electron apps) ignore it.",
                "窗口四角半径。0.1 是完全直角；超过 20 会开始像胶囊。要重开 app 才生效，自绘界面的 app（游戏、部分 Electron）不受影响。"),
 "win.sidebar-float": ("Tahoe made sidebars float as a rounded card. Off puts the sidebar back against the window edge, which returns several pixels of width and matches older macOS.",
                       "Tahoe 起侧边栏浮起成圆角卡片。关掉后侧边栏贴住窗口边，多回几个像素宽度，跟旧版 macOS 一致。"),
 "win.sidebar-radius": ("Only affects apps that use the glass sidebar material (Finder, Mail, Notes).",
                        "只影响用玻璃侧边栏材质的 app（Finder、邮件、备忘录）。"),
 "win.no-animations": ("Window open/close no longer animates. Launching an app looks instant instead of a 200 ms zoom.",
                       "开窗／关窗不再有动画，开 app 由 200ms 缩放变成即时。"),
 "win.resize-time": ("How long the window takes to follow your drag. 0.001 s is effectively immediate; the default rubber-band feel is about 0.2 s.",
                     "拖动窗口时跟手的速度。0.001 秒等于即时；默认大约 0.2 秒会有拉橡皮感。"),
 "win.save-expanded": ("Expanded panels let you type a path and see the whole tree; the collapsed one hides both.",
                       "展开版面板可以输入路径、看到完整目录；简化版两者都藏起来。"),
 "win.save-expanded2": ("Newer AppKit reads a second key for the same panel; setting both covers old and new apps.",
                        "新版 AppKit 用另一个 key 控制同一个面板，两个都设才覆盖新旧 app。"),
 "win.tableView-compact": ("Row height in every table view (Finder lists, Mail, Settings).",
                           "所有列表的行高（Finder、邮件、设置）。"),
 "win.dblclick-maximize": ("Linux and Windows both zoom on title-bar double-click; macOS minimises by default, which is the opposite of what most people expect.",
                           "Linux 和 Windows 双击标题栏都是放大；macOS 默认反而是缩到 Dock。"),
 "win.quicklook-instant": ("Space-bar preview appears without the grow animation.",
                           "空白键预览不再放大，直接出现。"),
 "kbd.repeat": ("Key repeat rate. 1 is the fastest the system allows; the default is 6 (~90 ms).",
                "按键重复速度。1 是系统允许的最快；默认是 6（约 90ms）。"),
 "kbd.repeat-initial": ("Delay before repeat starts. 10 is about 150 ms; the default is 25 (~500 ms).",
                        "开始重复前的延迟。10 约 150ms；默认 25（约 500ms）。"),
 "kbd.no-hold-popup": ("With the popup on, holding 'a' shows ā á ǎ à. Off means it repeats — what a terminal or editor expects.",
                       "开启时按住 a 会弹 ā á ǎ à；关掉就是重复，终端和编辑器需要的行为。"),
 "kbd.no-smart-quotes": ("macOS silently replaces \" with “ ” in text fields, which breaks code, SQL, JSON and shell commands.",
                         "macOS 会在文本框静静把 \" 换成 “ ”，破坏代码、SQL、JSON 和命令行。"),
 "kbd.no-smart-dashes": ("-- becomes — in text fields; command-line flags stop working when you paste them back.",
                         "文本框会把 -- 变成 —，命令行参数贴回去就失效。"),
 "kbd.no-autocorrect": ("No silent word replacement while typing.",
                        "打字时不会静静换掉你的字。"),
 "kbd.no-autocapitalize": ("No capital after a full stop or a new line.",
                           "句号或换行后不再自动大写。"),
 "kbd.no-text-completion": ("The grey inline suggestion that accepts on space.",
                            "灰色行内建议（按空白会接受）会关掉。"),
 "kbd.full-keyboard-access": ("Without this, Tab only moves between text fields and you cannot reach buttons from the keyboard.",
                              "不开的话 Tab 只在文字框之间跳，键盘去不到按钮。"),
 "dock.autohide": ("Dock slides away when not in use, giving back the bottom strip of the screen.",
                   "Dock 不用时收起，多回底部一条空间。"),
 "dock.autohide-delay": ("Removes the deliberate pause before the Dock appears.",
                         "取消 Dock 弹出前的刻意延迟。"),
 "dock.autohide-time": ("Animation length for show/hide; 0.15 s feels instant without looking broken.",
                        "出现／收起动画长度；0.15 秒感觉即时又不突兀。"),
 "dock.mineffect": ("genie stretches the window into the Dock; scale just shrinks it.",
                    "genie 会把窗口拉长吸入 Dock；scale 只是缩小。"),
 "dock.no-recents": ("The right-hand section of the Dock that fills with whatever you used last.",
                     "Dock 右边会自动填充最近用过的 app。"),
 "dock.expose-speed": ("Mission Control and Space switching animation length.",
                       "Mission Control 和切换 Space 的动画长度。"),
 "dock.no-launch-anim": ("The bounce an icon does while its app starts.",
                         "app 启动时图标弹跳的动画。"),
 "spaces.fixed-order": ("By default macOS reorders Spaces by how recently you used them, so keyboard shortcuts move under you. Fixed order keeps Space 3 where you put it.",
                        "macOS 默认按最近使用重排 Space，快捷键会跟着跑。固定顺序后 Space 3 永远在原位。"),
 "finder.extensions": ("Every file shows its extension, so two same-named files are distinguishable.",
                       "所有文件都显示扩展名，同名不同类的文件一眼分得出。"),
 "finder.pathbar": ("Shows where you are in the tree, and lets you jump up quickly.",
                    "显示你在目录树的哪一层，方便往上跳。"),
 "finder.statusbar": ("Item count and free space for the current folder.",
                      "当前文件夹的项目数和可用空间。"),
 "finder.fullpath": ("The title shows ~/dev/macfeel instead of macfeel.",
                     "标题显示 ~/dev/macfeel 而不是 macfeel。"),
 "finder.folders-first": ("Folders above files in every sort order.",
                          "任何排序方式下文件夹都在文件前面。"),
 "finder.no-ext-warning": ("You know what you are doing when you rename a file.",
                           "改扩展名是你自己决定的，不用每次确认。"),
 "finder.no-ds-network": ("Keeps SMB/NFS shares clean for other machines.",
                          "SMB／NFS 共享不会留下 .DS_Store 污染其他机器。"),
 "finder.no-ds-usb": ("Keeps USB sticks clean when you plug them into Linux or Windows.",
                      "USB 插到 Linux／Windows 上不会多出 .DS_Store。"),
 "shot.no-shadow": ("The shadow is baked into the PNG otherwise, which looks wrong pasted into a document.",
                    "否则阴影会烤进 PNG，贴进文件很难看。"),
 "shot.format": ("PNG is lossless; the default can end up as JPEG.",
                 "PNG 无损；默认可能会存成 JPEG。"),
 "shot.location": ("One folder instead of the desktop filling up.",
                   "统一一个文件夹，不会堆满桌面。"),
 "shot.no-thumbnail": ("The thumbnail that appears in the corner and covers your window.",
                       "右下角弹出来的缩略图会挡住画面。"),
 "ptr.natural-scroll": ("Natural scrolling moves content with your fingers; the Linux/Windows convention is the opposite. Pick whichever your hands expect.",
                        "自然滚动是内容跟着手指走；Linux／Windows 是相反方向。按你的习惯选。"),
 "ptr.linear-mouse": ("Pointer distance becomes proportional to hand distance. Takes effect after a logout, and the Tracking speed slider overwrites it — a stable curve needs an event tap, which needs Accessibility.",
                      "鼠标移动距离跟手成正比。要注销才生效，而且一拉追踪速度滑杆就会被覆盖 — 要稳定曲线需要事件拦截（Accessibility）。"),
 "ptr.tap-to-click": ("A light tap counts as a click; pressing the trackpad is no longer required.",
                      "轻点就当点击，不用按下去。"),
 "menubar.hide-fullscreen": ("Full-screen apps lose the top strip.",
                             "全屏 app 不再有顶部一条。"),
 "chrome.hide-menubar": ("The menu bar hides until the pointer reaches the top. Closest to a Linux full-screen feel, but you lose the clock and battery at a glance.",
                         "菜单栏平时隐藏，鼠标到顶部才出现。最像 Linux 全屏，但看不到时钟和电量。"),
}

UI = {
 "app.name": ("macfeel", "macfeel", "macfeel"),
 "app.tagline": ("Make macOS feel like Linux", "令 macOS 有 Linux 嘅手感", "让 macOS 有 Linux 的手感"),
 "ui.preset": ("PRESET", "預設組合", "预设组合"),
 "ui.dry": ("DRY RUN", "試跑", "试跑"),
 "ui.apply": ("APPLY", "套用", "应用"),
 "ui.restore": ("↩ RESTORE", "↩ 還原", "↩ 还原"),
 "ui.in-sync": ("IN SYNC", "已套用", "已应用"),
 "ui.drift": ("DRIFT", "值唔同", "值不同"),
 "ui.unset": ("UNSET", "未設定", "未设置"),
 "ui.revert": ("還原此項", "還原此項", "还原此项"),
 "ui.legend": ("IN SYNC means applied · DRIFT means a different value (apply overwrites it) · UNSET means macOS never set it · “restore this item” deletes the key and returns it to the system default",
               "IN SYNC means applied · DRIFT means a different value (apply overwrites it) · UNSET means macOS never set it · “restore this item” deletes the key and returns it to the system default",
               "IN SYNC 已应用 · DRIFT 值不同（可以覆盖） · UNSET 系统未设过 · 右边「还原此项」＝删除该 key，回到系统预设"),
 "ui.lede": ("{subtitle} — {count} items, {drift} not applied. Each row names the defaults key it writes; APPLY on the right changes only that row, APPLY above applies the whole preset.",
             "{subtitle} — {count} 項，{drift} 項未套用。每項下面寫住佢改邊個 defaults key；右邊 APPLY 只改嗰一項，上面 APPLY 一次過套用成個 preset。",
             "{subtitle} — {count} 项，{drift} 项未应用。每项下面写住它改哪个 defaults key；右边 APPLY 只改那一项，上面 APPLY 一次过套用整个 preset。"),
 "ui.footer": ("macfeel writes user-level preferences only — no Accessibility, no SIP changes. RESTORE returns to the state before macfeel ever ran.",
               "macfeel 只寫用戶層設定 — 唔需要 Accessibility、唔會改 SIP。RESTORE 會回到未改之前嘅狀態。",
               "macfeel 只写用户层设置 — 不需要 Accessibility、不会改 SIP。RESTORE 会回到未改之前的状态。"),
 "ui.language": ("Language", "語言", "语言"),
 "cli.already": ("already matches profile '{profile}' — nothing to do, no snapshot taken",
                 "已經同 preset '{profile}' 一致 — 冇嘢要做，唔會 snapshot",
                 "已经和 preset '{profile}' 一致 — 没有要做的，不会 snapshot"),
 "cli.dry": ("dry run — nothing will be written ({count} pending)",
             "試跑 — 唔會寫入任何嘢（{count} 項待改）",
             "试跑 — 不会写入任何东西（{count} 项待改）"),
 "cli.would": ("would set", "會設", "会设"),
 "cli.set": ("set", "已設", "已设"),
 "cli.failed": ("FAILED", "失敗", "失败"),
 "cli.snapshot": ("snapshot", "快照", "快照"),
 "cli.changed": ("changed {count}", "改咗 {count} 項", "改了 {count} 项"),
 "cli.dock": ("Dock restarted", "Dock 已重啟", "Dock 已重启"),
 "cli.finder": ("Finder restarted", "Finder 已重啟", "Finder 已重启"),
 "cli.uiserver": ("menu bar restarted", "選單列已重啟", "菜单栏已重启"),
 "cli.logout": ("some changes need a logout to take effect (mouse acceleration)",
                "有啲改動要登出再登入先生效（滑鼠加速）",
                "有些改动要注销再登录才生效（鼠标加速）"),
 "cli.restore-hint": ("undo: macfeel restore", "還原：macfeel restore", "还原：macfeel restore"),
 "cli.restored": ("restored {count} keys from {dir}", "由 {dir} 還原 {count} 個 key", "从 {dir} 还原 {count} 个 key"),
 "cli.no-snapshot": ("no snapshot recorded", "冇任何快照", "没有任何快照"),
 "cli.unknown": ("unknown command '{cmd}' (try: macfeel help)", "未知指令 '{cmd}'（試 macfeel help）", "未知命令 '{cmd}'（试 macfeel help）"),
 "cli.macos-only": ("this tool only runs on macOS", "呢個工具只行 macOS", "这个工具只跑 macOS"),
 "cli.about": ("MIT licence · https://github.com/Kinfxhk/macfeel", "MIT 授權 · https://github.com/Kinfxhk/macfeel", "MIT 授权 · https://github.com/Kinfxhk/macfeel"),
 "cli.coffee": ("if this helped: https://buymeacoffee.com/kinfxhk", "如果幫到你：https://buymeacoffee.com/kinfxhk", "如果帮到你：https://buymeacoffee.com/kinfxhk"),
 "cli.status.matched": ("already match profile '{profile}'", "已經同 preset '{profile}' 一致", "已经和 preset '{profile}' 一致"),
 "cli.doctor.sip": ("SIP", "SIP", "SIP"),
 "cli.doctor.profiles": ("profiles", "預設組合", "预设组合"),
 "cli.doctor.safety": ("macfeel never asks for Accessibility, never disables SIP, never touches system files.",
                       "macfeel 唔會要 Accessibility、唔會關 SIP、唔會改系統檔。",
                       "macfeel 不会要 Accessibility、不会关 SIP、不会改系统文件。"),
}

LANGS = ["en", "zh_Hant", "zh_Hans"]

zh_desc = read_tsv(ROOT / "lib" / "tweaks.conf")  # id -> desc (field 8 handled below)
desc_rows, note_rows = {}, {}
for line in (ROOT / "lib" / "tweaks.conf").read_text(encoding="utf-8").splitlines():
    if not line.strip() or line.startswith("#"):
        continue
    p = line.split("\t")
    if len(p) == 8:
        desc_rows[p[0]] = p[7]
for line in (ROOT / "lib" / "notes.conf").read_text(encoding="utf-8").splitlines():
    if not line.strip() or line.startswith("#"):
        continue
    p = line.split("\t")
    if len(p) >= 2:
        note_rows[p[0]] = p[1]

missing = [i for i in desc_rows if i not in DESC or i not in NOTE]
if missing:
    raise SystemExit(f"missing translations: {missing}")

with (I18N / "desc.tsv").open("w", encoding="utf-8") as f:
    f.write("# id\ten\tzh_Hant\tzh_Hans\n")
    for tid in sorted(desc_rows):
        en, hans = DESC[tid]
        f.write("\t".join([tid, en, desc_rows[tid], hans]) + "\n")

with (I18N / "notes.tsv").open("w", encoding="utf-8") as f:
    f.write("# id\ten\tzh_Hant\tzh_Hans\n")
    for tid in sorted(note_rows):
        en, hans = NOTE[tid]
        f.write("\t".join([tid, en, note_rows[tid], hans]) + "\n")

with (I18N / "ui.tsv").open("w", encoding="utf-8") as f:
    f.write("# key\ten\tzh_Hant\tzh_Hans\n")
    for key in UI:
        f.write("\t".join([key, *UI[key]]) + "\n")

print("wrote", len(desc_rows), "descs,", len(note_rows), "notes,", len(UI), "ui strings")
