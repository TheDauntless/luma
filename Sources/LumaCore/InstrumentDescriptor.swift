import Foundation

public struct InstrumentDescriptor: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: InstrumentKind
    public let sourceIdentifier: String
    public let displayName: String
    public let icon: InstrumentIcon
    public let compatibility: InstrumentCompatibility
    public let makeInitialConfigJSON: @Sendable () -> Data
    public let summarizeEvent: @Sendable (RuntimeEvent) -> String

    public init(
        id: String,
        kind: InstrumentKind,
        sourceIdentifier: String,
        displayName: String,
        icon: InstrumentIcon,
        compatibility: InstrumentCompatibility = .universal,
        makeInitialConfigJSON: @escaping @Sendable () -> Data,
        summarizeEvent: @escaping @Sendable (RuntimeEvent) -> String = { String(describing: $0.payload) }
    ) {
        self.id = id
        self.kind = kind
        self.sourceIdentifier = sourceIdentifier
        self.displayName = displayName
        self.icon = icon
        self.compatibility = compatibility
        self.makeInitialConfigJSON = makeInitialConfigJSON
        self.summarizeEvent = summarizeEvent
    }

    public static func == (lhs: InstrumentDescriptor, rhs: InstrumentDescriptor) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}