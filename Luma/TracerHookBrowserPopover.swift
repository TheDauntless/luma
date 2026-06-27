import LumaCore
import SwiftUI

struct TracerHookBrowserPopover: View {
    let sessionID: UUID
    let instanceID: UUID
    let hooks: [TracerConfig.Hook]
    @Binding var selection: SidebarItemID?
    let onDismiss: () -> Void

    var body: some View {
        SidebarBrowserPopover(
            placeholder: "Filter hooks",
            emptyMessage: "No matching hooks",
            items: hooks,
            groupName: { $0.addressAnchor.moduleGroupName },
            title: { $0.displayName },
            help: { $0.addressAnchor.displayString },
            isDimmed: { $0.state != .enabled },
            matches: { hook, query in
                hook.displayName.localizedCaseInsensitiveContains(query)
                    || hook.addressAnchor.moduleGroupName.localizedCaseInsensitiveContains(query)
                    || hook.addressAnchor.displayString.localizedCaseInsensitiveContains(query)
            },
            onChoose: { hook in
                selection = .instrumentComponent(sessionID, instanceID, hook.id)
                onDismiss()
            }
        )
    }
}
