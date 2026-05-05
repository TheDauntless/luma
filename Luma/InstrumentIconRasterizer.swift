import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum InstrumentIconRasterizer {
    static let maxDimension: CGFloat = 128

    static func normalize(_ raw: Data) -> Data? {
        #if os(macOS)
            guard let image = NSImage(data: raw) else { return nil }
            let target = scaledSize(for: image.size)
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(target.width),
                pixelsHigh: Int(target.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
            guard let bitmap else { return nil }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            image.draw(in: NSRect(origin: .zero, size: target))
            NSGraphicsContext.restoreGraphicsState()
            return bitmap.representation(using: .png, properties: [:])
        #else
            guard let image = UIImage(data: raw) else { return nil }
            let target = scaledSize(for: image.size)
            let renderer = UIGraphicsImageRenderer(size: target)
            let scaled = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
            return scaled.pngData()
        #endif
    }

    private static func scaledSize(for source: CGSize) -> CGSize {
        let longest = max(source.width, source.height)
        guard longest > maxDimension else { return source }
        let scale = maxDimension / longest
        return CGSize(width: floor(source.width * scale), height: floor(source.height * scale))
    }
}
