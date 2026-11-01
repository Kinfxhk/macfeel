# What the Linux crowd actually complains about

Collected from Hacker News threads ("To any Linux users, I recently bought a fully loaded M4",
"Apple forced me to switch to Linux"), r/linux, r/MacOS and lobste.rs discussions. Each row says
whether a preferences-level tool can touch it, and if not, what it would really take.

| Complaint | Fixable by prefs? | What macfeel does / what it would take |
|---|---|---|
| Mouse acceleration, pointer not 1:1 | **partly** | `com.apple.mouse.scaling -1` (needs logout, resets if you touch the Tracking speed slider). A stable curve needs an event tap → Accessibility. |
| Wheel scrolling feels like stairs | no | Needs an event tap to interpolate deltas. Not a preference. |
| Natural scrolling the wrong way | **yes** | `com.apple.swipescrolldirection false` |
| Key repeat too slow, or "hold for accents" | **yes** | `KeyRepeat 1`, `InitialKeyRepeat 10`, `ApplePressAndHoldEnabled false` |
| Smart quotes / autocorrect mangle code | **yes** | five `NSAutomatic*` keys, all off |
| Tab does not reach every control | **yes** | `AppleKeyboardUIMode 3` |
| Animations between you and every action | **yes** | window, resize, Quick Look, Dock launch, Mission Control durations |
| Windows have huge rounded corners | **yes** | `NSConvolutionOverride1` (`0.1` = square) |
| Double-clicking the title bar minimises | **yes** | `AppleActionOnDoubleClick Maximize` |
| Spaces reorder themselves by recent use | **yes** | `mru-spaces false` |
| Dock never leaves, bounces on launch | **yes** | `autohide`, `autohide-delay 0`, `launchanim false` |
| Screenshot thumbnail covers what you are doing | **yes** | `show-thumbnail false` |
| `.DS_Store` on network shares | **yes** | `DSDontWriteNetworkStores`, `DSDontWriteUSBStores` |
| **Focus follows mouse** | no | Needs the Accessibility API to raise/focus windows under the pointer. |
| **Cmd-Tab switches apps, not windows** | no | Needs an Accessibility window switcher. |
| **Middle-click paste** | no | Needs an event tap (X11-style primary selection has no macOS equivalent). |
| **Ctrl instead of Cmd** | no | Needs a keyboard remapper with Input Monitoring. |
| **i3-style tiling / workspaces** | no | macOS 15+ tiles natively (`fn`+`ctrl`+arrows); beyond that, a window manager with Accessibility. |
| **Window shadows and borders** | no | WindowServer private API — injection, not preferences. |

The honest split: **macOS gives you a lot of feel through user defaults, and nothing at all through
user defaults for input interception.** macfeel covers the first half completely and refuses to
pretend about the second.

## Provenance per key

| Key | Source / note |
|---|---|
| `NSConvolutionOverride1` | launchbad-revived README tip; MacRumors and r/MacOS threads. Works with SIP on, macOS 26/27. `0.1` sharp, `4` Catalina, `9` Sequoia, `16` Tahoe default. Do not use `-1`. |
| `NSSplitViewItemGlassMinimumCornerRadius` | same tip, Tahoe+ sidebar glass |
| `NSSplitViewItemSidebarDefaultsToFloatingAppearance` | same tip, edge-to-edge sidebar |
| `NSAutomaticWindowAnimationsEnabled`, `NSWindowResizeTime` | documented AppKit behaviour (`animationResizeTime(_:)` reads the default) |
| `KeyRepeat`, `InitialKeyRepeat`, `ApplePressAndHoldEnabled` | long-standing AppKit defaults |
| `AppleKeyboardUIMode` | AppKit "full keyboard access" (3 = all controls) |
| `AppleActionOnDoubleClick` | AppKit, `Maximize` / `Minimize` / `None` |
| `NSAutomaticQuoteSubstitutionEnabled` etc. | AppKit text machinery; mathiasbynens/dotfiles and many setups |
| `com.apple.dock` keys (`autohide*`, `mineffect`, `launchanim`, `mru-spaces`, `show-recents`, `expose-animation-duration`) | com.apple.dock preference domain |
| `com.apple.finder` keys | Finder preference domain |
| `com.apple.screencapture` keys | screencapture preference domain |
| `com.apple.mouse.scaling -1`, `com.apple.swipescrolldirection` | long-standing global prefs; scaling needs logout and is reset by the Tracking speed slider |

Verified on macOS 27.2 (build 26B123) with SIP enabled. Keys that a future macOS drops will show up
as `FAILED` in `macfeel apply` and as `drift` in `macfeel status` — the tool reports, it never hides.
