import SwiftUI
import LumaCore

struct CustomInstrumentUI: InstrumentUI {
    let defID: UUID

    func makeConfigEditor(
        configJSON: Binding<Data>,
        workspace: Workspace,
        selection: Binding<SidebarItemID?>
    ) -> AnyView {
        let id = defID
        let cfgBinding = Binding<CustomInstrumentConfig>(
            get: {
                (try? CustomInstrumentConfig.decode(from: configJSON.wrappedValue))
                    ?? CustomInstrumentConfig(defID: id)
            },
            set: { newValue in
                configJSON.wrappedValue = newValue.encode()
            }
        )
        return AnyView(
            CustomInstrumentConfigView(
                defID: id,
                config: cfgBinding,
                workspace: workspace,
                selection: selection
            )
        )
    }

    func renderEvent(
        _ event: RuntimeEvent,
        workspace: Workspace,
        selection: Binding<SidebarItemID?>
    ) -> AnyView {
        if case .jsValue(let v) = event.payload {
            return AnyView(
                JSInspectValueView(
                    value: v,
                    sessionID: event.sessionID ?? UUID(),
                    workspace: workspace,
                    selection: selection
                )
                .font(.system(.footnote, design: .monospaced))
            )
        }
        return AnyView(Text(String(describing: event.payload)))
    }
}
