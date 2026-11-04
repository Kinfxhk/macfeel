// Model.swift — the tweak table, read from the same TSV files the CLI uses,
// so there is exactly one source of truth for what macfeel changes.

import Foundation

enum TweakType: String {
    case bool, int, float, string
}

enum TweakValue: Equatable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)

    // MARK: display

    var display: String {
        switch self {
        case .bool(let b): return b ? "開" : "關"
        case .int(let i): return String(i)
        case .double(let d): return Self.trim(d)
        case .string(let s): return s
        }
    }

    /// Slider-friendly number, nil for bool/string.
    var number: Double? {
        switch self {
        case .int(let i): return Double(i)
        case .double(let d): return d
        default: return nil
        }
    }

    static func trim(_ d: Double) -> String {
        if d == d.rounded() { return String(Int(d)) }
        var s = String(format: "%.3f", d)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    // MARK: parsing

    static func parse(_ raw: String, type: TweakType) -> TweakValue? {
        switch type {
        case .bool:
            let v = raw.lowercased()
            if ["true", "yes", "1"].contains(v) { return .bool(true) }
            if ["false", "no", "0"].contains(v) { return .bool(false) }
            return nil
        case .int:
            return Int(raw).map(TweakValue.int)
        case .float:
            return Double(raw).map(TweakValue.double)
        case .string:
            return .string(raw)
        }
    }

    /// Machine-readable form for snapshots. Never use `display` for this:
    /// it is localised ("開"/"關") and cannot be parsed back.
    var canonical: String {
        switch self {
        case .bool(let b): return b ? "1" : "0"
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .string(let s): return s
        }
    }

    static func parseCanonical(_ raw: String, type: TweakType) -> TweakValue? {
        switch type {
        case .bool: return .bool(raw == "1" || raw.lowercased() == "true")
        case .int: return Int(raw).map(TweakValue.int)
        case .float: return Double(raw).map(TweakValue.double)
        case .string: return .string(raw)
        }
    }

    static func from(_ any: Any) -> TweakValue? {
        if let n = any as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return .bool(n.boolValue) }
            let d = n.doubleValue
            if d == d.rounded(), abs(d) < 9e15 { return .int(Int(d)) }
            return .double(d)
        }
        if let s = any as? String { return .string(s) }
        return nil
    }

    /// Drift detection: bool(true) and int(1) are the same setting to macOS,
    /// and "~/Pictures" vs the expanded path is the same location.
    func matches(_ other: TweakValue) -> Bool {
        if let a = number, let b = other.number { return abs(a - b) < 0.0005 }
        switch (self, other) {
        case (.bool(let a), .string(let b)): return (a ? "1" : "0") == b
        case (.string(let a), .bool(let b)): return a == (b ? "1" : "0")
        case (.string(let a), .string(let b)):
            let ea = (a as NSString).expandingTildeInPath
            let eb = (b as NSString).expandingTildeInPath
            return ea == eb
        case (.bool(let a), .bool(let b)): return a == b
        default: return false
        }
    }

    /// Bytes for `defaults write` (the CLI backend).
    var defaultsArguments: [String] {
        switch self {
        case .bool(let b): return ["-bool", b ? "YES" : "NO"]
        case .int(let i): return ["-int", String(i)]
        case .double(let d): return ["-float", String(d)]
        case .string(let s): return ["-string", s]
        }
    }

    /// Value for CFPreferences (the sandboxed backend).
    var preferencesObject: Any {
        switch self {
        case .bool(let b): return b
        case .int(let i): return i
        case .double(let d): return d
        case .string(let s): return s
        }
    }
}

struct Tweak: Identifiable, Equatable {
    let id: String
    let profiles: [String]
    let domain: String       // "-g" is the global domain
    let key: String
    let type: TweakType
    let value: TweakValue    // what this tweak sets
    let needs: String        // "-" | dock | finder | uiserver | relaunch | logout
    let label: String        // short name (zh)
    var note: String = ""    // long explanation (zh)
    var stockValue: TweakValue?   // macOS default; nil = the key is normally unset
    var range: (min: Double, max: Double, step: Double)?

    var isGlobal: Bool { domain == "-g" }

    /// The domain as CFPreferences / `defaults` name it.
    var effectiveDomain: String { isGlobal ? ".GlobalPreferences" : domain }

    var category: String {
        switch id.split(separator: ".").first.map(String.init) ?? id {
        case "win": return "視窗"
        case "dock": return "Dock"
        case "finder": return "Finder"
        case "kbd": return "鍵盤"
        case "shot": return "截圖"
        case "ptr": return "觸控板與滑鼠"
        case "chrome": return "選單列"
        case "spaces": return "Spaces"
        case "menubar": return "全螢幕"
        default: return "其他"
        }
    }

    var needsText: String? {
        switch needs {
        case "dock": return "Dock 會重啟"
        case "finder": return "Finder 會重啟"
        case "uiserver": return "選單列會重啟"
        case "relaunch": return "重開 app 才見到"
        case "logout": return "要登出才生效"
        default: return nil
        }
    }

    static func == (a: Tweak, b: Tweak) -> Bool { a.id == b.id }
}

struct Catalog {
    var tweaks: [Tweak]
    var i18n: [String: String]
    var language: String

    func t(_ key: String) -> String { i18n[key] ?? key }

    var categories: [(String, [Tweak])] {
        var order: [String] = []
        var bucket: [String: [Tweak]] = [:]
        for tw in tweaks {
            if bucket[tw.category] == nil { order.append(tw.category) }
            bucket[tw.category, default: []].append(tw)
        }
        return order.map { ($0, bucket[$0] ?? []) }
    }

    /// Cumulative presets: 標準 includes 輕量, 硬核 includes 標準.
    /// "chrome" is the opt-in menu-bar set and never rides along.
    func preset(_ level: String) -> [Tweak] {
        let rank = ["light": 1, "standard": 2, "hardcore": 3]
        guard let want = rank[level] else { return [] }
        return tweaks.filter { tw in
            tw.profiles.compactMap { rank[$0] }.contains { $0 <= want }
        }
    }

    // MARK: loading

    static func load(resourceDir: URL) -> Catalog {
        let tweaksRaw = rows(resourceDir.appendingPathComponent("tweaks.conf"))
        let stock = rows(resourceDir.appendingPathComponent("defaults.conf"))
        let ranges = rows(resourceDir.appendingPathComponent("ranges.conf"))
        let notes = rows(resourceDir.appendingPathComponent("notes.conf"))

        var stockByID: [String: String] = [:]
        for r in stock where r.count >= 2 { stockByID[r[0]] = r[1] }
        var rangeByID: [String: (Double, Double, Double)] = [:]
        for r in ranges where r.count >= 4 {
            if let a = Double(r[1]), let b = Double(r[2]), let c = Double(r[3]) { rangeByID[r[0]] = (a, b, c) }
        }
        var noteByID: [String: String] = [:]
        for r in notes where r.count >= 2 { noteByID[r[0]] = r[1] }

        var tweaks: [Tweak] = []
        for r in tweaksRaw where r.count >= 8 {
            guard let type = TweakType(rawValue: r[4]),
                  let value = TweakValue.parse(r[5], type: type) else { continue }
            var stockValue: TweakValue?
            if let raw = stockByID[r[0]], raw != "-" { stockValue = TweakValue.parse(raw, type: type) }
            var range: (min: Double, max: Double, step: Double)?
            if let rr = rangeByID[r[0]] { range = (rr.0, rr.1, rr.2) }
            tweaks.append(Tweak(id: r[0], profiles: r[1].split(separator: ",").map(String.init),
                                domain: r[2], key: r[3], type: type, value: value,
                                needs: r[6], label: r[7], note: noteByID[r[0]] ?? "",
                                stockValue: stockValue, range: range))
        }

        let lang = preferredLanguage()
        return Catalog(tweaks: tweaks, i18n: loadI18n(resourceDir.appendingPathComponent("ui.tsv"), lang), language: lang)
    }

    static func preferredLanguage() -> String {
        let code = (Locale.preferredLanguages.first ?? "en").lowercased()
        if code.hasPrefix("zh-hant") || code.hasPrefix("zh-tw") || code.hasPrefix("zh-hk") { return "zh_Hant" }
        if code.hasPrefix("zh") { return "zh_Hans" }
        return "en"
    }

    static func loadI18n(_ url: URL, _ lang: String) -> [String: String] {
        let col = ["en": 1, "zh_Hant": 2, "zh_Hans": 3][lang] ?? 1
        var table: [String: String] = [:]
        for r in rows(url) where r.count > col {
            table[r[0]] = r[col]
        }
        return table
    }

    /// TAB-separated rows, comments and blanks skipped. Empty fields are kept.
    static func rows(_ url: URL) -> [[String]] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { !$0.hasPrefix("#") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.components(separatedBy: "\t") }
    }
}
