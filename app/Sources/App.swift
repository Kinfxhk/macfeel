// App.swift — the window scene.

import SwiftUI
import AppKit

enum AppCatalog {
    static let shared: Catalog = Catalog.load(resourceDir: resourcesDir())
}

@MainActor
struct MacfeelApp: App {
    @StateObject private var engine: Engine

    init() {
        _engine = StateObject(wrappedValue: Engine(catalog: AppCatalog.shared, backend: BackendFactory.make()))
    }

    var body: some Scene {
        WindowGroup("macfeel") {
            RootView(engine: engine)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("重讀系統設定") { engine.refresh() }.keyboardShortcut("r")
            }
        }
    }
}
