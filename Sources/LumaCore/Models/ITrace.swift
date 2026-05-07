import Foundation
import GRDB

public struct ITrace: Codable, Identifiable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "itrace"

    public var id: UUID
    public var sessionID: UUID
    public var origin: Origin
    public var displayName: String
    public var startedAt: Date
    public var stoppedAt: Date?
    public var metadataJSON: Data
    public var dataSize: Int
    public var lost: Int

    public enum Origin: Codable, Sendable, Hashable {
        case functionCall(hookID: UUID, callIndex: Int)
        case thread(threadID: UInt, threadName: String?)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case origin
        case displayName = "display_name"
        case startedAt = "started_at"
        case stoppedAt = "stopped_at"
        case metadataJSON = "metadata_json"
        case dataSize = "data_size"
        case lost
    }

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        origin: Origin,
        displayName: String,
        startedAt: Date = Date(),
        stoppedAt: Date? = nil,
        metadataJSON: Data = Data(),
        dataSize: Int = 0,
        lost: Int = 0
    ) {
        self.id = id
        self.sessionID = sessionID
        self.origin = origin
        self.displayName = displayName
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
        self.metadataJSON = metadataJSON
        self.dataSize = dataSize
        self.lost = lost
    }

    public var isRunning: Bool { stoppedAt == nil }

    private static let wireEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.dataEncodingStrategy = .base64
        return e
    }()

    private static let wireDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.dataDecodingStrategy = .base64
        return d
    }()

    public func toWireJSON() -> [String: Any]? {
        guard let data = try? Self.wireEncoder.encode(self),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    public static func fromWireJSON(_ obj: [String: Any]) -> ITrace? {
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
            let trace = try? wireDecoder.decode(ITrace.self, from: data)
        else { return nil }
        return trace
    }
}
