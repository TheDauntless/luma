import LumaCore
import SwiftUI

struct ModuleAnalysisStatusIndicator: View {
    let status: ModuleAnalysisStatus

    var body: some View {
        switch status {
        case .analyzed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.green)
                .help("Analyzed")
        case .analyzing:
            ProgressView()
                .controlSize(.mini)
                .help("Analyzing\u{2026}")
        case .notAnalyzed:
            EmptyView()
        }
    }
}
