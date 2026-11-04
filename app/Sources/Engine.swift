// Engine.swift — current values, change plans, snapshots and restore.

import Foundation

struct Change: Identifiable {
    let tweak: Tweak
    let from: TweakValue?
    let to: TweakValue
    var id: String { tweak.id }
}

struct ApplyResult {
    var changed: Int = 0
    var failed: [String] = []
    var restarted: [String] = []
    var stillDifferent: [String] = []
}

struct SnapshotEntry: Codable {
    let id: String
    let domain: String
    let key: String
    let type: String
    let value: String?      // nil = the key did not exist
}

struct Snapshot: Codable {
    let createdAt: Date
    let entries: [SnapshotEntry]
}

@MainActor
final class Engine: ObservableObject {
    let catalog: Catalog
    let backend: PreferencesBackend
    let snapshotDir: URL

    @Published private(set) var revision = 0
    @Published private(set) var status: String = ""

    private var cache: [String: [String: Any]] = [:]

    init(catalog: Catalog, backend: PreferencesBackend, snapshotDir: URL = Engine.snapshotDir) {
        self.catalog = catalog
        self.backend = backend
        self.snapshotDir = snapshotDir
        refresh()
    }

    // MARK: reading

    func refresh() {
        var next: [String: [String: Any]] = [:]
        for domain in Set(catalog.tweaks.map(\.effectiveDomain)) {
            next[domain] = backend.exportDomain(domain)
        }
        cache = next
        revision += 1
    }

    func value(for tweak: Tweak) -> TweakValue? {
        // Rows outside the catalogue (the probe used by --selftest) are read live.
        if cache[tweak.effectiveDomain] == nil {
            return backend.exportDomain(tweak.effectiveDomain)[tweak.key].flatMap(TweakValue.from)
        }
        guard let raw = cache[tweak.effectiveDomain]?[tweak.key] else { return nil }
        return TweakValue.from(raw)
    }

    func matchesTarget(_ tweak: Tweak) -> Bool {
        value(for: tweak)?.matches(tweak.value) ?? false
    }

    // MARK: planning

    func plan(for tweaks: [Tweak]) -> [Change] {
        tweaks.compactMap { tw in
            let now = value(for: tw)
            if let now, now.matches(tw.value) { return nil }
            return Change(tweak: tw, from: now, to: tw.value)
        }
    }

    // MARK: applying

    @discardableResult
    func apply(_ changes: [Change]) -> ApplyResult {
        var result = ApplyResult()
        guard !changes.isEmpty else { return result }

        _ = takeSnapshot()

        for change in changes {
            do {
                try backend.write(change.tweak, change.to)
                result.changed += 1
            } catch {
                result.failed.append(change.tweak.id)
            }
        }
        refresh()

        // A write can report success and still not land — re-read to be sure.
        for change in changes where !matchesTarget(change.tweak) {
            result.stillDifferent.append(change.tweak.id)
        }

        var hints: [String] = []
        for change in changes {
            let h = change.tweak.needs
            if ["dock", "finder", "uiserver"].contains(h), !hints.contains(h) { hints.append(h) }
        }
        if backend.canRestartShell {
            for hint in hints where backend.restart(hint) { result.restarted.append(hint) }
        }

        var parts = ["改了 \(result.changed) 項"]
        if !result.failed.isEmpty { parts.append("失敗 \(result.failed.count) 項") }
        if !result.stillDifferent.isEmpty { parts.append("未生效 \(result.stillDifferent.count) 項") }
        if !result.restarted.isEmpty {
            parts.append(result.restarted.map { $0 == "dock" ? "Dock 已重啟" : $0 == "finder" ? "Finder 已重啟" : "選單列已重啟" }.joined(separator: " · "))
        }
        if !hints.isEmpty && !backend.canRestartShell {
            parts.append("要登出或重開 app 才生效")
        }
        status = parts.joined(separator: " · ")
        return result
    }

    // MARK: single row

    func applyRow(_ tweak: Tweak, value: TweakValue) {
        apply([Change(tweak: tweak, from: self.value(for: tweak), to: value)])
    }

    func revertRow(_ tweak: Tweak) {
        backend.delete(tweak)
        refresh()
        status = "已還原 \(tweak.label)"
    }

    func note(_ text: String) { status = text }

    // MARK: snapshots

    nonisolated static var supportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
        return base.appendingPathComponent("macfeel", isDirectory: true)
    }

    nonisolated static var snapshotDir: URL { supportDir.appendingPathComponent("snapshots", isDirectory: true) }

    @discardableResult
    func takeSnapshot(tweaks: [Tweak]? = nil) -> URL? {
        let entries = (tweaks ?? catalog.tweaks).map { tw in
            SnapshotEntry(id: tw.id, domain: tw.domain, key: tw.key, type: tw.type.rawValue,
                          value: value(for: tw)?.canonical)
        }
        let snap = Snapshot(createdAt: Date(), entries: entries)
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        let name = fmt.string(from: snap.createdAt).replacingOccurrences(of: ":", with: "-") + ".json"
        let dir = snapshotDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(snap) else { return nil }
        try? data.write(to: url)
        return url
    }

    func latestSnapshot() -> (URL, Snapshot)? {
        snapshots().last
    }

    /// The snapshot taken before macfeel first changed anything here.
    func earliestSnapshot() -> (URL, Snapshot)? {
        snapshots().first
    }

    private func snapshots() -> [(URL, Snapshot)] {
        let dir = snapshotDir
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        let sorted = files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var out: [(URL, Snapshot)] = []
        for url in sorted {
            if let data = try? Data(contentsOf: url) {
                let dec = JSONDecoder()
                dec.dateDecodingStrategy = .iso8601
                if let snap = try? dec.decode(Snapshot.self, from: data) { out.append((url, snap)) }
            }
        }
        return out
    }

    @discardableResult
    func restoreLatest() -> Int { restore(latestSnapshot(), label: "最近") }

    /// The footer button: back to the state before macfeel first ran here.
    @discardableResult
    func restoreEarliest() -> Int { restore(earliestSnapshot(), label: "最早") }

    @discardableResult
    private func restore(_ found: (URL, Snapshot)?, label: String) -> Int {
        guard let (url, snap) = found else {
            status = "沒有任何快照"
            return 0
        }
        var count = 0
        let byID = Dictionary(uniqueKeysWithValues: catalog.tweaks.map { ($0.id, $0) })
        for entry in snap.entries {
            // Entries carry their own domain/key/type so a snapshot still restores
            // after a tweak is renamed or dropped from the table.
            let tw = byID[entry.id] ?? Tweak(id: entry.id, profiles: [], domain: entry.domain,
                                             key: entry.key,
                                             type: TweakType(rawValue: entry.type) ?? .string,
                                             value: .string(""), needs: "-", label: entry.id)
            if let raw = entry.value, let v = TweakValue.parseCanonical(raw, type: tw.type) {
                if (try? backend.write(tw, v)) != nil { count += 1 }
            } else {
                backend.delete(tw)
                count += 1
            }
        }
        for hint in ["dock", "finder", "uiserver"] where backend.canRestartShell {
            _ = backend.restart(hint)
        }
        refresh()
        let fmt = DateFormatter()
        fmt.dateFormat = "MM-dd HH:mm"
        status = "由 \(label)快照（\(fmt.string(from: snap.createdAt))）還原 \(count) 項"
        return count
    }

    // MARK: self test

    /// Round-trips a throwaway domain and a throwaway snapshot directory, so the
    /// engine can be tested without reading or writing any real setting.
    static func selfTest(catalog: Catalog, backend: PreferencesBackend) -> Int32 {
        var failures = 0
        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            print("\(ok ? "PASS" : "FAIL")\t\(name)\t\(detail)")
            if !ok { failures += 1 }
        }

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("macfeel-selftest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let engine = Engine(catalog: catalog, backend: backend, snapshotDir: temp)
        let probe = Tweak(id: "selftest.probe", profiles: [], domain: "com.kinfxhk.macfeel.selftest",
                          key: "probe", type: .float, value: .double(0.25), needs: "-", label: "selftest")
        print("# backend=\(backend.name) sandboxed=\(BackendFactory.isSandboxed) tweaks=\(catalog.tweaks.count)")

        // 1. write + read back through the backend's own export
        try? backend.write(probe, .double(0.5))
        let readBack = backend.exportDomain(probe.effectiveDomain)[probe.key].flatMap(TweakValue.from)
        check("roundtrip.write", readBack?.matches(.double(0.5)) ?? false, "read=\(readBack?.display ?? "nil")")

        // 2. every type survives
        for value in [TweakValue.int(7), .bool(true), .string("scale"), .double(0.15)] {
            try? backend.write(probe, value)
            let got = backend.exportDomain(probe.effectiveDomain)[probe.key].flatMap(TweakValue.from)
            check("roundtrip.\(value.canonical)", got?.matches(value) ?? false, "read=\(got?.display ?? "nil")")
        }

        // 3. snapshot -> change -> restore, on the probe only (the snapshot holds
        //    just this one entry, so no real preference is written by the test)
        engine.refresh()   // the cache was built before the probe writes above
        let url = engine.takeSnapshot(tweaks: [probe])
        check("snapshot.write", url != nil, url?.lastPathComponent ?? "nil")
        var canonicalOK = false
        var debugDetail = "no file"
        if let url, let data = try? Data(contentsOf: url) {
            let raw = String(data: data, encoding: .utf8) ?? ""
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            if let snap = try? dec.decode(Snapshot.self, from: data) {
                canonicalOK = snap.entries.contains {
                    $0.id == probe.id && abs((Double($0.value ?? "") ?? -1) - 0.15) < 0.001
                }
                debugDetail = snap.entries.map { "\($0.id)=\($0.value ?? "nil")" }.joined(separator: ",")
            } else {
                debugDetail = "decode failed: " + raw.prefix(240)
            }
        }
        check("snapshot.canonical", canonicalOK, debugDetail)
        try? backend.write(probe, .double(9.5))
        let restored = engine.restoreLatest()
        let afterRestore = backend.exportDomain(probe.effectiveDomain)[probe.key].flatMap(TweakValue.from)
        check("restore", afterRestore?.matches(.double(0.15)) ?? false, "restored=\(restored) read=\(afterRestore?.display ?? "nil")")

        // 4. delete leaves the key absent
        backend.delete(probe)
        check("delete", backend.exportDomain(probe.effectiveDomain)[probe.key] == nil)

        // 5. catalogue reads: every tweak resolves without crashing (read-only)
        var present = 0
        for tw in catalog.tweaks where engine.value(for: tw) != nil { present += 1 }
        check("read.all", true, "\(present)/\(catalog.tweaks.count) 個 tweak 目前有值")

        // 6. the plan never includes a row that already matches
        let plan = engine.plan(for: catalog.preset("standard"))
        let clean = plan.allSatisfy { !engine.matchesTarget($0.tweak) }
        check("plan.noop", clean, "\(plan.count) 項待改")

        print("# \(failures == 0 ? "ALL PASS" : "\(failures) FAILED")")
        return failures == 0 ? 0 : 1
    }
}
