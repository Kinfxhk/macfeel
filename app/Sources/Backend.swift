// Backend.swift — how macfeel actually writes preferences.
//
// Two implementations, chosen by entitlement at build time:
//   CLIBackend  — spawns /usr/bin/defaults, can also restart Dock/Finder.
//                 Used by the Developer ID build (no sandbox).
//   CFBackend   — pure CFPreferences, works inside App Sandbox *with* the
//                 temporary-exception entitlement. Cannot signal other apps.
//
// Measured on macOS 27.2: a sandboxed app without the exception writes into its
// own container and reads the value back happily — the real plist never changes.
// So never judge success by the write call; read the domain again.

import Foundation
import AppKit

struct PreferencesError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

protocol PreferencesBackend {
    /// Can this build restart Dock / Finder / the menu bar?
    var canRestartShell: Bool { get }
    var name: String { get }

    func exportDomain(_ domain: String) -> [String: Any]
    func write(_ tweak: Tweak, _ value: TweakValue) throws
    func delete(_ tweak: Tweak)
    /// Returns true when the process was actually restarted.
    func restart(_ hint: String) -> Bool
}

// MARK: - Developer ID build

final class CLIBackend: PreferencesBackend {
    let canRestartShell = true
    var name: String { "defaults" }

    private let defaults = "/usr/bin/defaults"

    func exportDomain(_ domain: String) -> [String: Any] {
        let args = domain == ".GlobalPreferences" ? ["export", "-g", "-"] : ["export", domain, "-"]
        let out = run(args)
        guard let data = out.data(using: .utf8), !data.isEmpty,
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return plist
    }

    func write(_ tweak: Tweak, _ value: TweakValue) throws {
        var args = ["write", tweak.isGlobal ? "-g" : tweak.domain, tweak.key]
        args += value.defaultsArguments
        let result = runCapturing(args)
        if result.status != 0 {
            throw PreferencesError(message: result.stderr.isEmpty ? "defaults write failed (\(result.status))" : result.stderr)
        }
    }

    func delete(_ tweak: Tweak) {
        _ = run(["delete", tweak.isGlobal ? "-g" : tweak.domain, tweak.key])
    }

    func restart(_ hint: String) -> Bool {
        let bundle: String
        switch hint {
        case "dock": bundle = "com.apple.dock"
        case "finder": bundle = "com.apple.finder"
        case "uiserver": bundle = "com.apple.systemuiserver"
        default: return false
        }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else { return false }
        return app.terminate()
    }

    private func run(_ args: [String]) -> String {
        runCapturing(args).stdout
    }

    private func runCapturing(_ args: [String]) -> (status: Int32, stdout: String, stderr: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: defaults)
        p.arguments = args
        let o = Pipe(), e = Pipe()
        p.standardOutput = o
        p.standardError = e
        do { try p.run() } catch { return (-1, "", error.localizedDescription) }
        let od = o.fileHandleForReading.readDataToEndOfFile()
        let ed = e.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus,
                String(data: od, encoding: .utf8) ?? "",
                (String(data: ed, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

// MARK: - Mac App Store build

final class CFBackend: PreferencesBackend {
    let canRestartShell = false
    var name: String { "CFPreferences" }

    private func appID(_ tweak: Tweak) -> CFString {
        tweak.isGlobal ? kCFPreferencesAnyApplication : (tweak.domain as CFString)
    }

    func exportDomain(_ domain: String) -> [String: Any] {
        let app = domain == ".GlobalPreferences" ? kCFPreferencesAnyApplication : (domain as CFString)
        let all = CFPreferencesCopyMultiple(nil, app, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: Any]
        return all ?? [:]
    }

    func write(_ tweak: Tweak, _ value: TweakValue) throws {
        CFPreferencesSetValue(tweak.key as CFString, value.preferencesObject as CFTypeRef,
                              appID(tweak), kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        if !CFPreferencesSynchronize(appID(tweak), kCFPreferencesCurrentUser, kCFPreferencesAnyHost) {
            // Synchronize returns false when nothing was written or the write was refused;
            // the caller verifies by re-reading, which is the only trustworthy signal.
            return
        }
    }

    func delete(_ tweak: Tweak) {
        CFPreferencesSetValue(tweak.key as CFString, nil, appID(tweak),
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        _ = CFPreferencesSynchronize(appID(tweak), kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    func restart(_ hint: String) -> Bool { false }
}

enum BackendFactory {
    static var isSandboxed: Bool {
        NSHomeDirectory().contains("/Library/Containers/")
    }

    static func make() -> PreferencesBackend {
        isSandboxed ? CFBackend() : CLIBackend()
    }
}
