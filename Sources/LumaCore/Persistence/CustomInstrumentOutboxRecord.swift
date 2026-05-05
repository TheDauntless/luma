import Foundation
import GRDB

struct CustomInstrumentOutboxRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "custom_instrument_outbox"

    var opID: String
    var kind: String
    var defID: String
    var payloadJSON: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case opID = "op_id"
        case kind
        case defID = "def_id"
        case payloadJSON = "payload_json"
        case createdAt = "created_at"
    }

    func toOp() -> CustomInstrumentOp? {
        guard let data = payloadJSON.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return CustomInstrumentOp.fromJSON(obj)
    }
}
