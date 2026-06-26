import Foundation

extension JSInspectValue {
    public static func fromJSONText(_ text: String) -> JSInspectValue? {
        guard let data = text.data(using: .utf8),
            let root = try? JSONSerialization.jsonObject(with: data)
        else { return nil }

        var counter = 0
        func nextID() -> Int {
            counter += 1
            return counter
        }

        func convert(_ value: Any) -> JSInspectValue {
            switch value {
            case let dict as [String: Any]:
                return .object(id: nextID(), properties: dict.map {
                    Property(key: .string($0.key), value: convert($0.value))
                })
            case let array as [Any]:
                return .array(id: nextID(), elements: array.map(convert))
            case let number as NSNumber:
                if CFGetTypeID(number) == CFBooleanGetTypeID() {
                    return .boolean(number.boolValue)
                }
                return .number(number.doubleValue)
            case let string as String:
                return .string(string)
            case is NSNull:
                return .null
            default:
                return .string(String(describing: value))
            }
        }

        return convert(root)
    }
}
