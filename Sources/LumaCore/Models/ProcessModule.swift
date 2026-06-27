public struct ModuleDelta: Sendable {
    public let added: [ProcessModule]
    public let removed: [ProcessModule]

    public init(added: [ProcessModule] = [], removed: [ProcessModule] = []) {
        self.added = added
        self.removed = removed
    }

    public var isEmpty: Bool { added.isEmpty && removed.isEmpty }

    public func applied(to base: [ProcessModule]?) -> [ProcessModule] {
        var result = base ?? []
        if !removed.isEmpty {
            let removedBases = Set(removed.map { $0.base })
            result.removeAll { removedBases.contains($0.base) }
        }
        result.append(contentsOf: added)
        return result
    }
}

extension Sequence where Element == ProcessModule {
    public func sortedByOrigin() -> [ProcessModule] {
        sorted { lhs, rhs in
            if lhs.isSystemModule != rhs.isSystemModule { return !lhs.isSystemModule }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

public struct ProcessModule: Hashable, Identifiable, Codable, Sendable {
    public var id: String { "\(path)@0x\(String(base, radix: 16))" }
    public let name: String
    public let path: String
    public let base: UInt64
    public let size: UInt64

    public init(name: String, path: String, base: UInt64, size: UInt64) {
        self.name = name
        self.path = path
        self.base = base
        self.size = size
    }

    private static let systemPathPrefixes = ["/usr/lib", "/usr/local/lib", "/System/", "/Library/", "/lib/", "/lib64/", "/opt/"]

    public var isSystemModule: Bool {
        let windows = path.lowercased()
        if windows.contains(":\\windows\\") || windows.hasPrefix("\\windows\\") {
            return true
        }
        return Self.systemPathPrefixes.contains { path.hasPrefix($0) }
    }

    public func toJSON() -> [String: Any] {
        return [
            "name": name,
            "path": path,
            "base": String(format: "0x%llx", base),
            "size": Int(size),
        ]
    }

    public static func fromJSON(_ obj: [String: Any]) -> ProcessModule? {
        guard let name = obj["name"] as? String,
            let path = obj["path"] as? String,
            let baseStr = obj["base"] as? String,
            let size = obj["size"] as? Int
        else { return nil }

        let base = UInt64(baseStr.dropFirst(2), radix: 16) ?? 0
        return ProcessModule(name: name, path: path, base: base, size: UInt64(size))
    }
}
