import Foundation
import Gtk
import LumaCore

@MainActor
enum InstrumentIconView {
    static func makeImage(for icon: InstrumentIcon, pixelSize: Int) -> Image {
        switch icon {
        case .symbolic(let id):
            let image = Image(iconName: InstrumentIconCatalog.concept(forID: id).symbolicIcon)
            image.pixelSize = pixelSize
            return image
        case .pixels(let data):
            return IconPixbuf.makeImage(fromPNGData: data, pixelSize: pixelSize)
                ?? fallbackImage(pixelSize: pixelSize)
        }
    }

    private static func fallbackImage(pixelSize: Int) -> Image {
        let image = Image(iconName: "application-x-executable-symbolic")
        image.pixelSize = pixelSize
        return image
    }
}
