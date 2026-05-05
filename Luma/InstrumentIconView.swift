import SwiftUI
import LumaCore

struct InstrumentIconView: View {
    let icon: InstrumentIcon
    var pointSize: CGFloat = 12

    var body: some View {
        switch icon {
        case .symbolic(let id):
            Image(systemName: InstrumentIconCatalog.concept(forID: id).sfSymbol)
                .font(.system(size: pointSize))
        case .pixels(let data):
            pixelsImage(data: data)
        }
    }

    @ViewBuilder
    private func pixelsImage(data: Data) -> some View {
        #if canImport(AppKit)
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: pointSize, height: pointSize)
            } else {
                fallback
            }
        #elseif canImport(UIKit)
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: pointSize, height: pointSize)
            } else {
                fallback
            }
        #else
            fallback
        #endif
    }

    private var fallback: some View {
        Image(systemName: "questionmark.square.dashed")
            .font(.system(size: pointSize))
    }
}
