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
