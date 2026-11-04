// main.swift — top-level entry point.
//
//   macfeel                  open the panel
//   macfeel --selftest       headless engine test (writes only to a scratch domain)
//   macfeel --dump           print every setting's current value
//   macfeel --plan <level>   print what a preset would change, write nothing

import Foundation
import AppKit

func resourcesDir() -> URL {
    if let r = Bundle.main.resourceURL,
       FileManager.default.fileExists(atPath: r.appendingPathComponent("tweaks.conf").path) {
        return r
    }
    // Running from the repo during development: app/Sources -> app/Resources
    let here = URL(fileURLWithPath: #filePath)
    return here.deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Resources")
}

let catalog = Catalog.load(resourceDir: resourcesDir())
let arguments = CommandLine.arguments

// Top-level code runs on the main thread; the engine is @MainActor.
let exitCode: Int32? = MainActor.assumeIsolated {
    if arguments.contains("--selftest") {
        return Engine.selfTest(catalog: catalog, backend: BackendFactory.make())
    }

    if arguments.contains("--dump") {
        let engine = Engine(catalog: catalog, backend: BackendFactory.make())
        print("# backend=\(engine.backend.name) tweaks=\(catalog.tweaks.count)")
        for tw in catalog.tweaks {
            let now = engine.value(for: tw)
            let state = now == nil ? "UNSET" : (engine.matchesTarget(tw) ? "OK" : "DRIFT")
            print("\(state)\t\(tw.id)\t\(tw.domain)\t\(tw.key)\t\(now?.display ?? "-")\t-> \(tw.value.display)")
        }
        return 0
    }

    if arguments.contains("--env") {
        print("bundle=\(Bundle.main.bundleIdentifier ?? "nil")")
        print("standard.theme=\(UserDefaults.standard.string(forKey: "theme") ?? "nil")")
        print("settings.theme=\(AppSettings.theme.rawValue)")
        print("sandboxed=\(BackendFactory.isSandboxed) backend=\(BackendFactory.make().name)")
        return 0
    }

    if arguments.contains("--write-test") {
        // Proves the shipping build can really write another app's domain: write a
        // throwaway key to com.apple.dock, read it back through the backend, delete it.
        let backend = BackendFactory.make()
        let probe = Tweak(id: "write.probe", profiles: [], domain: "com.apple.dock",
                          key: "macfeelWriteProbe", type: .string, value: .string("1"),
                          needs: "-", label: "probe")
        backend.delete(probe)
        try? backend.write(probe, .string("1"))
        let landed = backend.exportDomain("com.apple.dock")["macfeelWriteProbe"].flatMap(TweakValue.from)
        // MACFEEL_KEEP_PROBE=1 leaves the key behind so an unsandboxed shell can
        // read the real plist — the only way to prove a sandboxed write escaped
        // its container.
        if ProcessInfo.processInfo.environment["MACFEEL_KEEP_PROBE"] != "1" {
            backend.delete(probe)
        }
        let clean = backend.exportDomain("com.apple.dock")["macfeelWriteProbe"] == nil
        print("\(landed?.matches(.string("1")) == true ? "PASS" : "FAIL")\tcom.apple.dock write\tread=\(landed?.display ?? "nil")")
        print("\(clean ? "PASS" : "FAIL")\tcom.apple.dock cleanup")
        return (landed != nil && clean) ? 0 : 1
    }

    if let i = arguments.firstIndex(of: "--plan"), i + 1 < arguments.count {
        let level = arguments[i + 1]
        let engine = Engine(catalog: catalog, backend: BackendFactory.make())
        let changes = engine.plan(for: catalog.preset(level))
        print("# plan \(level): \(changes.count) changes (nothing written)")
        for c in changes {
            print("\(c.tweak.id)\t\(c.from?.display ?? "UNSET") -> \(c.to.display)")
        }
        return 0
    }
    return nil
}

if let code = exitCode { exit(code) }

MacfeelApp.main()
