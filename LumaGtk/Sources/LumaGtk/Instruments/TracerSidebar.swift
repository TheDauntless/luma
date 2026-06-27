import Foundation
import Gtk
import LumaCore

@MainActor
enum TracerSidebar {
    static let inlineLimit = 5

    static func makeHookRow(hook: TracerConfig.Hook, status: InstrumentStatus?) -> (row: ListBoxRow, anchor: Box) {
        SidebarFeatureRow.make(
            icon: makeHookKindIcon(kind: hook.kind),
            title: hook.displayName,
            dimmed: hook.state == .disabled,
            tooltip: hook.addressAnchor.displayString,
            accessory: status.map { InstrumentStatusPopover.makeIndicator(status: $0) }
        )
    }

    static func makeBrowseAllRow(totalCount: Int) -> (row: ListBoxRow, anchor: Box) {
        SidebarFeatureRow.makeBrowseAll(totalCount: totalCount)
    }

    static func presentBrowser(
        hooks: [TracerConfig.Hook],
        anchor: Widget,
        onChoose: @escaping @MainActor (TracerConfig.Hook) -> Void
    ) {
        let browser = SidebarBrowserPopover(
            items: hooks,
            placeholder: "Filter hooks",
            emptyMessage: "No matching hooks",
            groupName: { $0.addressAnchor.moduleGroupName },
            title: { $0.displayName },
            tooltip: { $0.addressAnchor.displayString },
            dimmed: { $0.state == .disabled },
            matches: { hook, query in
                hook.displayName.localizedCaseInsensitiveContains(query)
                    || hook.addressAnchor.moduleGroupName.localizedCaseInsensitiveContains(query)
                    || hook.addressAnchor.displayString.localizedCaseInsensitiveContains(query)
            },
            onChoose: onChoose
        )
        browser.presentAnchored(to: anchor)
    }

    private static func makeHookKindIcon(kind: TracerHookKind) -> Widget {
        let label = Label(str: "")
        label.useMarkup = true
        switch kind {
        case .function:
            label.label = "<span size=\"medium\">𝑓</span>"
        case .instruction:
            label.label = "<i>i</i>"
        }
        label.hexpand = true
        label.halign = .center
        label.valign = .center
        label.add(cssClass: "dim-label")
        return label
    }
}
