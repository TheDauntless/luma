import Foundation
import Observation

@Observable
@MainActor
public final class CustomInstrumentLibrary {
    public private(set) var defs: [CustomInstrumentDef] = []

    @ObservationIgnored public var observers: [@MainActor () -> Void] = []
    @ObservationIgnored private var observation: StoreObservation?

    public init() {}

    public func start(store: ProjectStore) {
        defs = Self.normalizeAndPersistIfChanged(
            (try? store.fetchCustomInstrumentDefs()) ?? [],
            store: store
        )
        observation = store.observeCustomInstrumentDefs { [weak self, store] defs in
            let healed = Self.normalizeAndPersistIfChanged(defs, store: store)
            Task { @MainActor in
                self?.applyChange(defs: healed)
            }
        }
    }

    nonisolated private static func normalizeAndPersistIfChanged(
        _ defs: [CustomInstrumentDef],
        store: ProjectStore
    ) -> [CustomInstrumentDef] {
        defs.map { def in
            var copy = def
            copy.normalize()
            if copy != def {
                try? store.save(copy)
            }
            return copy
        }
    }

    public func def(withId id: UUID) -> CustomInstrumentDef? {
        defs.first { $0.id == id }
    }

    public func descriptors() -> [InstrumentDescriptor] {
        defs.map(descriptor(for:))
    }

    public func descriptor(for def: CustomInstrumentDef) -> InstrumentDescriptor {
        let defID = def.id
        let initialFeatures = initialFeatureStates(for: def)
        return InstrumentDescriptor(
            id: "custom:\(defID.uuidString)",
            kind: .custom,
            sourceIdentifier: defID.uuidString,
            displayName: def.name,
            icon: def.icon,
            compatibility: def.compatibility,
            makeInitialConfigJSON: {
                CustomInstrumentConfig(defID: defID, features: initialFeatures).encode()
            }
        )
    }

    public static func initialFeatureStates(for def: CustomInstrumentDef) -> [String: FeatureState] {
        Dictionary(uniqueKeysWithValues: def.features.map {
            ($0.id, FeatureState(enabled: $0.enabledByDefault, value: $0.schema.defaultValue))
        })
    }

    private func initialFeatureStates(for def: CustomInstrumentDef) -> [String: FeatureState] {
        Self.initialFeatureStates(for: def)
    }

    private func applyChange(defs: [CustomInstrumentDef]) {
        self.defs = defs
        for observer in observers { observer() }
    }
}
