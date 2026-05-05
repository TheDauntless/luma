import Foundation
import Observation

@Observable
@MainActor
public final class HookPackLibrary {
    public private(set) var packs: [HookPack] = []

    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
        reload()
    }

    public func reload() {
        packs = discover()
    }

    public func pack(withId id: String) -> HookPack? {
        packs.first { $0.manifest.id == id }
    }

    public func descriptors() -> [InstrumentDescriptor] {
        packs.map { pack in
            let icon = hookPackIcon(pack: pack)

            let packID = pack.manifest.id
            let defaultEnabled = Dictionary(
                uniqueKeysWithValues: pack.manifest.features
                    .filter(\.defaultEnabled)
                    .map { ($0.id, FeatureConfig()) }
            )

            return InstrumentDescriptor(
                id: "hook-pack:\(packID)",
                kind: .hookPack,
                sourceIdentifier: packID,
                displayName: pack.manifest.name,
                icon: icon,
                makeInitialConfigJSON: {
                    try! JSONEncoder().encode(
                        HookPackConfig(packId: packID, features: defaultEnabled)
                    )
                }
            )
        }
    }

    private func hookPackIcon(pack: HookPack) -> InstrumentIcon {
        let fallback = InstrumentIcon.symbolic("puzzle")
        guard let iconMeta = pack.manifest.icon else { return fallback }
        if let file = iconMeta.file {
            let fileURL = pack.folderURL.appendingPathComponent(file)
            if let data = try? Data(contentsOf: fileURL) {
                return .pixels(data)
            }
        }
        if let symbol = iconMeta.symbolic {
            return .symbolic(symbol)
        }
        return fallback
    }

    private func discover() -> [HookPack] {
        let fm = FileManager.default
        guard
            let contents = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        var result: [HookPack] = []
        for url in contents {
            guard
                let rv = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                rv.isDirectory == true
            else { continue }

            let manifestURL = url.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifestURL) else { continue }

            do {
                let manifest = try JSONDecoder().decode(HookPackManifest.self, from: data)
                result.append(HookPack(manifest: manifest, folderURL: url))
            } catch {
                print("Failed to decode hook-pack manifest at \(manifestURL): \(error)")
            }
        }

        return result
    }
}
