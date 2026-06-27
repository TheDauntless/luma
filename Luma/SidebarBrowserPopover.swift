import LumaCore
import SwiftUI

struct SidebarBrowserPopover<Item: Identifiable>: View {
    let placeholder: String
    let emptyMessage: String
    let items: [Item]
    let groupName: (Item) -> String
    let title: (Item) -> String
    let help: (Item) -> String
    let isDimmed: (Item) -> Bool
    let matches: (Item, String) -> Bool
    let onChoose: (Item) -> Void

    @State private var query: String = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Divider()
            resultsList
        }
        .padding(.vertical, 10)
        .frame(width: 360, height: 420)
        .onAppear { isSearchFocused = true }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit { selectFirstMatch() }
        }
        .padding(.horizontal, 12)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedMatches) { group in
                    Section {
                        ForEach(group.items) { item in
                            itemButton(for: item)
                        }
                    } header: {
                        groupHeader(group.name, count: group.items.count)
                    }
                }
                if groupedMatches.isEmpty {
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    private func groupHeader(_ name: String, count: Int) -> some View {
        HStack {
            Text(name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.background)
    }

    private func itemButton(for item: Item) -> some View {
        Button {
            onChoose(item)
        } label: {
            HStack(spacing: 6) {
                Text(title(item))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .opacity(isDimmed(item) ? 0.5 : 1)
            .help(help(item))
        }
        .buttonStyle(.plain)
    }

    private var groupedMatches: [BrowserGroup<Item>] {
        let filtered = filteredItems
        guard !filtered.isEmpty else { return [] }
        var byName: [String: [Item]] = [:]
        var order: [String] = []
        for item in filtered {
            let key = groupName(item)
            if byName[key] == nil { order.append(key) }
            byName[key, default: []].append(item)
        }
        return order.map { BrowserGroup(name: $0, items: byName[$0] ?? []) }
    }

    private var filteredItems: [Item] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { matches($0, trimmed) }
    }

    private func selectFirstMatch() {
        guard let first = filteredItems.first else { return }
        onChoose(first)
    }
}

private struct BrowserGroup<Item: Identifiable>: Identifiable {
    let name: String
    let items: [Item]
    var id: String { name }
}
