import Foundation

public enum CustomInstrumentOp: Sendable {
    case upsert(Upsert)
    case remove(Remove)

    public var opID: UUID {
        switch self {
        case .upsert(let u): return u.opID
        case .remove(let r): return r.opID
        }
    }

    public var defID: UUID {
        switch self {
        case .upsert(let u): return u.def.id
        case .remove(let r): return r.defID
        }
    }

    public var kind: String {
        switch self {
        case .upsert: return "upsert"
        case .remove: return "remove"
        }
    }

    public struct Upsert: Sendable {
        public let opID: UUID
        public var def: CustomInstrumentDef

        public init(opID: UUID = UUID(), def: CustomInstrumentDef) {
            self.opID = opID
            self.def = def
        }
    }

    public struct Remove: Sendable {
        public let opID: UUID
        public let defID: UUID

        public init(opID: UUID = UUID(), defID: UUID) {
            self.opID = opID
            self.defID = defID
        }
    }

    public func toJSON() -> [String: Any] {
        var obj: [String: Any] = [
            "op_id": opID.uuidString,
            "kind": kind,
        ]
        switch self {
        case .upsert(let u):
            obj["def"] = u.def.toJSON()
        case .remove(let r):
            obj["def_id"] = r.defID.uuidString
        }
        return obj
    }

    public static func fromJSON(_ obj: [String: Any]) -> CustomInstrumentOp? {
        guard let opIDStr = obj["op_id"] as? String,
            let opID = UUID(uuidString: opIDStr),
            let kind = obj["kind"] as? String
        else { return nil }

        switch kind {
        case "upsert":
            guard let defObj = obj["def"] as? [String: Any],
                let def = CustomInstrumentDef.fromJSON(defObj)
            else { return nil }
            return .upsert(Upsert(opID: opID, def: def))
        case "remove":
            guard let defIDStr = obj["def_id"] as? String,
                let defID = UUID(uuidString: defIDStr)
            else { return nil }
            return .remove(Remove(opID: opID, defID: defID))
        default:
            return nil
        }
    }
}
