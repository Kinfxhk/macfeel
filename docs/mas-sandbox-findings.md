# macfeel under App Sandbox — measured results

Measured on macOS 27.2 (26B123), Xcode 27.2, 2026-11-04, with the probe in
`~/dev/macfeel-spike` (one `main.swift`, three `.app` bundles that differ only in
entitlements). Every result below was verified by reading the real preference
plists **from outside** the app — a sandboxed CFPreferences write reports success
inside its own container while the system plist never changes.

## What the numbers were

| Build | Real preference writes that landed |
|---|---|
| no entitlement (control) | 7/7 attempted |
| `com.apple.security.app-sandbox` only | **0/10** |
| sandbox + `temporary-exception.shared-preference.read-write` | **7/7 attempted** |

The sandboxed-without-exception build is the dangerous case: `UserDefaults(suiteName:)`
returns the value it just "wrote", so an app that trusts its write call will look
like it works and change nothing.

## The entitlement list that works

```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.temporary-exception.shared-preference.read-write</key>
<array>
    <string>com.apple.dock</string>
    <string>com.apple.finder</string>
    <string>com.apple.screencapture</string>
    <string>com.apple.AppleMultitouchTrackpad</string>
    <string>kCFPreferencesAnyApplication</string>
</array>
```

- The **global domain** (everything written with `-g`) is granted by the literal string
  `kCFPreferencesAnyApplication`. `.GlobalPreferences`, `NSGlobalDomain` and
  `GlobalPreferences` do **not** grant it — measured one by one, combined with
  `com.apple.dock` so the app-domain grant was known to work in the same build.
- A bare executable carrying `app-sandbox` dies in `libsecinit_appsandbox` with
  SIGTRAP ("Info.plist from code signature has no kCFBundleIdentifier") before `main()`.
  The variant must be a real `.app` bundle.
- `NSGlobalDomain` as a `UserDefaults` suite name logs
  `Using NSGlobalDomain as an NSUserDefaults suite name does not make sense` and fails;
  use `.GlobalPreferences` for reads or `kCFPreferencesAnyApplication` for writes.

## What still does not work in the sandbox

- **Terminating Dock / Finder / SystemUIServer**: `NSRunningApplication.terminate()`
  returns false under the sandbox (it returns true unsandboxed). A Mac App Store build
  must ask the user to log out or relaunch instead of restarting the Dock itself.
- **Spawning `/usr/bin/defaults`** inherits the parent's grants, so it works for domains
  the exception lists and fails for the rest — but it is pointless inside the sandbox;
  the CFPreferences path is the one to ship.

## Consequence for the product

One SwiftUI shell, two backends (`app/Sources/Backend.swift`):

- `CLIBackend` — `/usr/bin/defaults` + `NSRunningApplication.terminate()`: the
  Developer ID / GitHub build, full behaviour.
- `CFBackend` — pure CFPreferences: the App Sandbox build, writes work, restarts do not.

The remaining unknown is not technical: App Review judges
`temporary-exception.*` entitlements case by case, so a rejection is a schedule risk,
not a bug.
