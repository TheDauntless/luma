import LumaCore
import SwiftUI
import SwiftyMonaco

struct CodeEditorView: View {
    @Binding var text: String
    let profile: EditorProfile
    var introspector: MonacoIntrospector? = nil
    var focused: Binding<Bool>? = nil
    let engine: Engine

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        var themedProfile = profile
        themedProfile.theme = colorScheme == .dark ? .gitHubDark : .gitHubLight

        let monacoProfile = MonacoEditorProfile(from: themedProfile)
        let snapshot = engine.editorFSSnapshot.map { MonacoFSSnapshot(from: $0) }

        var editor = SwiftyMonaco(text: $text, profile: monacoProfile)
            .fsSnapshot(snapshot)

        if let introspector {
            editor = editor.introspector(introspector)
        }

        if let focused {
            editor = editor.focused(focused)
        }

        return editor
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(editorBorderColor)
                    .frame(height: 1)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(editorBorderColor)
                    .frame(width: 1)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(editorBorderColor)
                    .frame(height: 1)
                    .allowsHitTesting(false)
            }
            .task {
                await engine.rebuildEditorFSSnapshotIfNeeded()
            }
    }

    private var editorBorderColor: Color {
        colorScheme == .dark
            ? Color(red: 0x2A / 255.0, green: 0x2B / 255.0, blue: 0x2C / 255.0)
            : Color(red: 0xF0 / 255.0, green: 0xF1 / 255.0, blue: 0xF2 / 255.0)
    }
}
