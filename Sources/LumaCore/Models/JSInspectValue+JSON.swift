import Foundation

extension JSInspectValue {
    public static func fromJSONText(_ text: String) -> JSInspectValue? {
        guard let data = text.data(using: .utf8),
            let root = try? JSONDecoder().decode(RawJSONValue.self, from: data)
        else { return nil }

        var counter = 0
        func nextID() -> Int {
            counter += 1
            return counter
        }

        func convert(_ value: RawJSONValue) -> JSInspectValue {
            switch value {
            case .object(let fields):
                return .object(id: nextID(), properties: fields.map {
                    Property(key: .string($0.key), value: convert($0.value))
                })
            case .array(let elements):
                return .array(id: nextID(), elements: elements.map(convert))
            case .boolean(let flag):
                return .boolean(flag)
            case .number(let value):
                return .number(value)
            case .string(let value):
                return .string(value)
            case .null:
                return .null
            }
        }

        return convert(root)
    }
}

private enum RawJSONValue: Decodable {
    case object([String: RawJSONValue])
    case array([RawJSONValue])
    case boolean(Bool)
    case number(Double)
    case string(String)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let flag = try? container.decode(Bool.self) {
            self = .boolean(flag)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let elements = try? container.decode([RawJSONValue].self) {
            self = .array(elements)
        } else {
            self = .object(try container.decode([String: RawJSONValue].self))
        }
    }
}
