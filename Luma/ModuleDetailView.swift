import LumaCore
import SwiftUI

struct ModuleDetailView: View {
    let sessionID: UUID
    let module: LumaCore.ProcessModule
    @ObservedObject var workspace: Workspace
    @Binding var selection: SidebarItemID?

    @State private var bundles: [LumaCore.ProcessModule.ID: LumaCore.ModuleSymbolBundle] = [:]
    @State private var loadErrors: [LumaCore.ProcessModule.ID: String] = [:]
    @State private var tab: Tab = .exports
    @State private var selectedRowID: String?

    enum Tab: String, CaseIterable, Identifiable {
        case exports = "Exports"
        case imports = "Imports"
        case symbols = "Symbols"

        var id: String { rawValue }
    }

    private var bundle: LumaCore.ModuleSymbolBundle? { bundles[module.id] }
    private var loadError: String? { loadErrors[module.id] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(label(for: t)).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            content
        }
        .padding(.top, 8)
        .task(id: module.id) {
            guard bundle == nil, loadError == nil else { return }
            await load(module)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let loadError {
            Text(loadError).foregroundStyle(.red)
        } else if let bundle {
            switch tab {
            case .exports: exportsTable(bundle.exports)
            case .imports: importsTable(bundle.imports)
            case .symbols: symbolsTable(bundle.symbols)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    private func label(for tab: Tab) -> String {
        guard let bundle else { return tab.rawValue }
        switch tab {
        case .exports: return "Exports (\(bundle.exports.count))"
        case .imports: return "Imports (\(bundle.imports.count))"
        case .symbols: return "Symbols (\(bundle.symbols.count))"
        }
    }

    private func exportsTable(_ rows: [LumaCore.ModuleSymbolBundle.Export]) -> some View {
        Table(rows, selection: $selectedRowID) {
            TableColumn("Name", value: \.name)
            TableColumn("Type") { e in Text(e.kind.rawValue) }
            TableColumn("Address") { e in
                addressCell(address: e.address)
            }
        }
        .frame(minHeight: 240, idealHeight: 360)
        .contextMenu(forSelectionType: String.self) { ids in
            if let id = ids.first, let row = rows.first(where: { $0.id == id }) {
                addressMenu(
                    address: row.address,
                    title: row.name,
                    context: addressContext(for: row.kind)
                )
            }
        } primaryAction: { ids in
            if let id = ids.first, let row = rows.first(where: { $0.id == id }) {
                openInsight(at: row.address, title: row.name, context: addressContext(for: row.kind))
            }
        }
    }

    private func importsTable(_ rows: [LumaCore.ModuleSymbolBundle.Import]) -> some View {
        Table(rows, selection: $selectedRowID) {
            TableColumn("Name", value: \.name)
            TableColumn("Module") { i in Text(i.module ?? "—") }
            TableColumn("Type") { i in Text(i.kind?.rawValue ?? "—") }
            TableColumn("Address") { i in
                if let addr = i.address {
                    addressCell(address: addr)
                } else {
                    Text("—")
                }
            }
        }
        .frame(minHeight: 240, idealHeight: 360)
        .contextMenu(forSelectionType: String.self) { ids in
            if let id = ids.first,
                let row = rows.first(where: { $0.id == id }),
                let address = row.address
            {
                addressMenu(
                    address: address,
                    title: row.name,
                    context: row.kind.map(addressContext(for:)) ?? AddressContext()
                )
            }
        } primaryAction: { ids in
            if let id = ids.first,
                let row = rows.first(where: { $0.id == id }),
                let address = row.address
            {
                openInsight(
                    at: address,
                    title: row.name,
                    context: row.kind.map(addressContext(for:)) ?? AddressContext()
                )
            }
        }
    }

    private func symbolsTable(_ rows: [LumaCore.ModuleSymbolBundle.Symbol]) -> some View {
        Table(rows, selection: $selectedRowID) {
            TableColumn("Name", value: \.name)
            TableColumn("Type") { s in Text(s.type) }
            TableColumn("Section") { s in Text(s.sectionID ?? "—") }
            TableColumn("Size") { s in
                Text(s.size.map { String(format: "0x%x", $0) } ?? "—")
                    .font(.system(.body, design: .monospaced))
            }
            TableColumn("Address") { s in
                addressCell(address: s.address)
            }
        }
        .frame(minHeight: 240, idealHeight: 360)
        .contextMenu(forSelectionType: String.self) { ids in
            if let id = ids.first, let row = rows.first(where: { $0.id == id }) {
                addressMenu(
                    address: row.address,
                    title: row.name,
                    context: addressContext(for: row)
                )
            }
        } primaryAction: { ids in
            if let id = ids.first, let row = rows.first(where: { $0.id == id }) {
                openInsight(at: row.address, title: row.name, context: addressContext(for: row))
            }
        }
    }

    private func addressCell(address: UInt64) -> some View {
        Text(String(format: "0x%llx", address))
            .font(.system(.body, design: .monospaced))
    }

    @ViewBuilder
    private func addressMenu(address: UInt64, title: String, context: AddressContext) -> some View {
        Button {
            openInsight(at: address, title: title, kindOverride: .disassembly)
        } label: {
            Label("Open Disassembly", systemImage: "hammer")
        }

        Button {
            openInsight(at: address, title: title, kindOverride: .memory)
        } label: {
            Label("Open Memory", systemImage: "doc.text.magnifyingglass")
        }

        let actions = workspace.engine.addressActions(sessionID: sessionID, address: address, context: context)
        if !actions.isEmpty {
            Divider()
            ForEach(actions) { action in
                Button(role: action.role == .destructive ? .destructive : nil) {
                    Task { @MainActor in
                        if let target = await action.perform() {
                            selection = workspace.sidebarItem(for: target)
                        }
                    }
                } label: {
                    if let icon = action.systemImage {
                        Label(action.title, systemImage: icon)
                    } else {
                        Text(action.title)
                    }
                }
            }
        }
    }

    private func openInsight(
        at address: UInt64,
        title: String,
        context: AddressContext = AddressContext(),
        kindOverride: LumaCore.AddressInsight.Kind? = nil
    ) {
        let kind: LumaCore.AddressInsight.Kind
        if let kindOverride {
            kind = kindOverride
        } else if context.kind == .data {
            kind = .memory
        } else {
            kind = .disassembly
        }

        Task { @MainActor in
            do {
                let insight = try workspace.engine.getOrCreateInsight(
                    sessionID: sessionID,
                    pointer: address,
                    kind: kind
                )
                selection = .insight(sessionID, insight.id)
            } catch {
                loadErrors[module.id] = error.localizedDescription
            }
        }
    }

    private func load(_ module: LumaCore.ProcessModule) async {
        guard let node = workspace.engine.node(forSessionID: sessionID) else {
            loadErrors[module.id] = "Process is detached."
            return
        }
        do {
            let result = try await node.enumerateModuleSymbols(name: module.name)
            bundles[module.id] = result
            loadErrors.removeValue(forKey: module.id)
        } catch {
            loadErrors[module.id] = error.localizedDescription
        }
    }
}

private func addressContext(for kind: LumaCore.ModuleSymbolBundle.SymbolKind) -> AddressContext {
    switch kind {
    case .function: return AddressContext(kind: .function, typeHint: "function")
    case .variable: return AddressContext(kind: .data, typeHint: "variable")
    }
}

private func addressContext(for symbol: LumaCore.ModuleSymbolBundle.Symbol) -> AddressContext {
    if symbol.isCode {
        return AddressContext(kind: .function, typeHint: symbol.type)
    }
    if symbol.isData {
        return AddressContext(kind: .data, typeHint: symbol.type)
    }
    return AddressContext(kind: .unspecified, typeHint: symbol.type)
}

private func defaultInsightLabel(for context: AddressContext) -> String {
    context.kind == .data ? "Open Memory" : "Open Disassembly"
}

private func defaultInsightIcon(for context: AddressContext) -> String {
    context.kind == .data ? "doc.text.magnifyingglass" : "hammer"
}
