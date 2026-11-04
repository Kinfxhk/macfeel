// Views.swift — the panel. One line per setting, the long explanation behind ⓘ.

import SwiftUI

struct RootView: View {
    @ObservedObject var engine: Engine

    @State private var themeMode: ThemeMode = ThemeMode(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "auto") ?? .auto
    @State private var expanded: Set<String> = []
    @State private var presetLevel: String?
    @State private var confirmingRestore = false
    @AppStorage("theme") private var storedTheme: String = "auto"

    private var catalog: Catalog { engine.catalog }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Palette.rule)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(catalog.categories, id: \.0) { category, tweaks in
                        sectionHeader(category, tweaks)
                        ForEach(tweaks) { tweak in
                            RowView(engine: engine, tweak: tweak, expanded: $expanded)
                            Divider().overlay(Palette.rule.opacity(0.6)).padding(.leading, 18)
                        }
                    }
                    Color.clear.frame(height: 12)
                }
            }
            Divider().overlay(Palette.rule)
            footer
        }
        .background(Palette.paper)
        .tint(Palette.accent)
        .frame(minWidth: 760, minHeight: 640)
        .onAppear { ThemeMode.apply(storedTheme); themeMode = ThemeMode(rawValue: storedTheme) ?? .auto }
        .sheet(item: Binding(get: { presetLevel.map { PresetRequest(level: $0) } },
                             set: { presetLevel = $0?.level })) { request in
            ChangeSheet(engine: engine,
                        level: request.level,
                        tweaks: catalog.preset(request.level))
        }
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("macfeel")
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text(catalog.t("app.tagline"))
                    .font(.callout)
                    .foregroundStyle(Palette.muted)
                Spacer()
                Picker("", selection: Binding(get: { themeMode }, set: { mode in
                    themeMode = mode
                    storedTheme = mode.rawValue
                    ThemeMode.apply(mode.rawValue)
                })) {
                    ForEach(ThemeMode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 110)
            }

            HStack(spacing: 10) {
                ForEach([("light", "輕量"), ("standard", "標準"), ("hardcore", "硬核")], id: \.0) { level, name in
                    Button {
                        presetLevel = level
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(name).font(.system(size: 14, weight: .semibold))
                            Text("\(catalog.preset(level).count) 項").font(.caption2).foregroundStyle(Palette.muted)
                        }
                        .frame(width: 96, alignment: .leading)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.nav))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.rule, lineWidth: 1))
                        .foregroundStyle(Palette.ink)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            HStack(spacing: 6) {
                Text("點一下預覽改動，確認後才寫入").font(.system(size: 10)).foregroundStyle(Palette.muted)
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(Palette.nav)
    }

    private func sectionHeader(_ name: String, _ tweaks: [Tweak]) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Palette.muted)
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    // MARK: footer

    private var footer: some View {
        HStack(spacing: 10) {
            if !engine.status.isEmpty {
                Text(engine.status).font(.caption).foregroundStyle(Palette.ink).lineLimit(2)
            } else {
                Text(catalog.t("ui.footer")).font(.caption2).foregroundStyle(Palette.muted).lineLimit(2)
            }
            Spacer()
            Button("快照") { engine.takeSnapshot(); engine.note("已建立快照") }
                .buttonStyle(.plain).font(.caption).foregroundStyle(Palette.muted)
            Button("還原") { confirmingRestore = true }
                .buttonStyle(.plain).font(.caption).foregroundStyle(Palette.accent)
                .confirmationDialog("還原到最早的快照？", isPresented: $confirmingRestore) {
                    Button("還原所有改動", role: .destructive) { engine.restoreEarliest() }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("會把 macfeel 改過的鍵值回復到第一次執行之前，並重啟 Dock／Finder。")
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Palette.nav)
    }
}

private struct PresetRequest: Identifiable {
    let level: String
    var id: String { level }
}

// MARK: - one setting

struct RowView: View {
    @ObservedObject var engine: Engine
    let tweak: Tweak
    @Binding var expanded: Set<String>

    @State private var pending: TweakValue?

    private var current: TweakValue? { engine.value(for: tweak) }
    private var shown: TweakValue { pending ?? current ?? tweak.value }
    private var dirty: Bool {
        guard let now = current else { return true }
        return !shown.matches(now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(tweak.label)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                chip
                Button {
                    if expanded.contains(tweak.id) { expanded.remove(tweak.id) } else { expanded.insert(tweak.id) }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(expanded.contains(tweak.id) ? Palette.accent : Palette.muted)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 12)
                control.frame(width: controlWidth)
                if dirty {
                    Button("套用") { engine.applyRow(tweak, value: shown); pending = nil }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                }
            }
            if expanded.contains(tweak.id) { detail }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(dirty ? Palette.accent.opacity(0.05) : Color.clear)
    }

    private var controlWidth: CGFloat {
        switch tweak.type {
        case .bool: return 46
        case .string: return 200
        default: return tweak.range == nil ? 90 : 240
        }
    }

    private var chip: some View {
        Group {
            if current == nil {
                Text("未設定").foregroundStyle(Palette.muted)
            } else if engine.matchesTarget(tweak) {
                Text("符合").foregroundStyle(Palette.ok)
            } else {
                Text("值不同").foregroundStyle(Palette.warn)
            }
        }
        .font(.system(size: 10, weight: .medium))
        .padding(.horizontal, 6).padding(.vertical, 2)
        .overlay(Capsule().stroke(Palette.rule, lineWidth: 0.8))
    }

    @ViewBuilder private var control: some View {
        switch tweak.type {
        case .bool:
            Toggle("", isOn: Binding(
                get: { if case .bool(let b) = shown { return b } else { return false } },
                set: { pending = .bool($0) }))
            .toggleStyle(.switch).labelsHidden()
        case .string:
            TextField("", text: Binding(
                get: { if case .string(let s) = shown { return s } else { return "" } },
                set: { pending = .string($0) }))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12, design: .monospaced))
        case .int, .float:
            if let range = tweak.range {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Slider(value: Binding(
                            get: { shown.number ?? range.min },
                            set: { newValue in
                                pending = tweak.type == .int ? .int(Int(newValue.rounded())) : .double(newValue)
                            }), in: range.min...range.max, step: range.step)
                        .tint(Palette.accent)
                        Text(shown.display)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 42, alignment: .trailing)
                    }
                    TickTrack(min: range.min, max: range.max, step: range.step,
                              stock: tweak.stockValue?.number)
                    HStack {
                        Text(TweakValue.trim(range.min)).font(.system(size: 9)).foregroundStyle(Palette.muted)
                        Spacer()
                        Text("預設 \(tweak.stockValue?.display ?? "—")")
                            .font(.system(size: 9)).foregroundStyle(Palette.muted)
                        Spacer()
                        Text(TweakValue.trim(range.max)).font(.system(size: 9)).foregroundStyle(Palette.muted)
                    }
                }
            } else {
                TextField("", text: Binding(
                    get: { shown.display },
                    set: { text in
                        if tweak.type == .int, let i = Int(text) { pending = .int(i) }
                        if tweak.type == .float, let d = Double(text) { pending = .double(d) }
                    }))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
            }
        }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tweak.note.isEmpty ? tweak.label : tweak.note)
                .font(.system(size: 11))
                .foregroundStyle(Palette.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                Text("\(tweak.isGlobal ? "-g" : tweak.domain) · \(tweak.key)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                Text("原生 \(tweak.stockValue?.display ?? "—")")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted)
                if let needs = tweak.needsText {
                    Text(needs).font(.system(size: 10)).foregroundStyle(Palette.warn)
                }
                Button("還原此項") { engine.revertRow(tweak); pending = nil }
                    .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(Palette.accent)
            }
        }
        .padding(.top, 2)
        .padding(.trailing, 20)
    }
}

// MARK: - tick track under a slider

struct TickTrack: View {
    let min: Double
    let max: Double
    let step: Double
    let stock: Double?

    /// Evenly spaced ticks, thinned out so a 0.001–0.5 slider does not draw 500 marks.
    private var ticks: [Double] {
        guard step > 0, self.max > self.min else { return [] }
        let span = self.max - self.min
        let wanted = Swift.min(9, span / step)          // at most ~10 marks
        let stride = step * Double(Swift.max(1, Int((span / step / wanted).rounded())))
        var out: [Double] = [self.min]
        var v = self.min + stride
        while v < self.max - 0.0001 && out.count < 11 {
            out.append(v)
            v += stride
        }
        out.append(self.max)
        return out
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                Rectangle().fill(Palette.rule).frame(height: 1)
                ForEach(ticks, id: \.self) { t in
                    Rectangle().fill(Palette.muted.opacity(0.5))
                        .frame(width: 1, height: 5)
                        .offset(x: width(geo, t))
                }
                if let s = stock, max > min {
                    Rectangle().fill(Palette.accent)
                        .frame(width: 2, height: 8)
                        .offset(x: width(geo, s))
                }
            }
        }
        .frame(height: 9)
    }

    private func width(_ geo: GeometryProxy, _ value: Double) -> CGFloat {
        let clamped = Swift.max(min, Swift.min(max, value))
        return geo.size.width * CGFloat((clamped - min) / (max - min))
    }
}

// MARK: - change list before applying a preset

struct ChangeSheet: View {
    @ObservedObject var engine: Engine
    let level: String
    let tweaks: [Tweak]

    @Environment(\.dismiss) private var dismiss
    private var changes: [Change] { engine.plan(for: tweaks) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("套用\(levelName)組合").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(changes.count) 項會改動").font(.caption).foregroundStyle(Palette.muted)
            }
            .padding(16)

            Divider().overlay(Palette.rule)

            if changes.isEmpty {
                Text("已與這個組合一致，冇需要改動。")
                    .font(.callout).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(changes) { change in
                            HStack(alignment: .firstTextBaseline) {
                                Text(change.tweak.label)
                                    .font(.system(size: 12))
                                    .frame(width: 190, alignment: .leading)
                                Text(change.from?.display ?? "未設定")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Palette.muted)
                                    .frame(width: 70, alignment: .trailing)
                                Text("→").font(.system(size: 11)).foregroundStyle(Palette.muted)
                                Text(change.to.display)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Palette.accent)
                                    .frame(width: 70, alignment: .leading)
                                if let needs = change.tweak.needsText {
                                    Text(needs).font(.system(size: 9)).foregroundStyle(Palette.warn)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                }
            }

            Divider().overlay(Palette.rule)
            HStack {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("接受並套用") {
                    engine.apply(changes)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(changes.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 620, height: 460)
        .background(Palette.paper)
    }

    private var levelName: String {
        switch level {
        case "light": return "輕量"
        case "standard": return "標準"
        default: return "硬核"
        }
    }
}
