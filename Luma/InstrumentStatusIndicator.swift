import LumaCore
import SwiftUI

struct InstrumentStatusIndicator: View {
    let status: InstrumentStatus

    @State private var isShowingPopover = false

    var body: some View {
        Button {
            isShowingPopover.toggle()
        } label: {
            Image(systemName: status.iconName)
                .font(.system(size: 10))
                .foregroundStyle(status.tint)
        }
        .buttonStyle(.plain)
        .help(status.summary)
        .popover(isPresented: $isShowingPopover, arrowEdge: .trailing) {
            InstrumentStatusPopover(status: status)
        }
    }
}

private struct InstrumentStatusPopover: View {
    let status: InstrumentStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: status.iconName)
                    .foregroundStyle(status.tint)
                Text(status.headline)
                    .font(.headline)
            }
            if status.summary != status.headline {
                Text(status.summary)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let stack = status.stack, !stack.isEmpty {
                Divider()
                ScrollView([.vertical, .horizontal]) {
                    Text(stack)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: true)
                        .padding(.trailing, 4)
                }
                .frame(maxWidth: 960, maxHeight: 480)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .frame(minWidth: 320, maxWidth: 980, alignment: .leading)
    }
}

extension InstrumentStatus {
    var iconName: String {
        switch self {
        case .incompatible:
            return "exclamationmark.triangle.fill"
        case .loadFailed, .reloadFailed, .configInvalid:
            return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .incompatible:
            return .orange
        case .loadFailed, .reloadFailed, .configInvalid:
            return .red
        }
    }

    var headline: String {
        switch self {
        case .incompatible: return "Incompatible"
        case .loadFailed: return "Failed to load"
        case .reloadFailed: return "Failed to reload"
        case .configInvalid: return "Compilation failed"
        }
    }
}
