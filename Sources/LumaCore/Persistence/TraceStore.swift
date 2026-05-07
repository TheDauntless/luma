import Foundation

public final class TraceStore: Sendable {
    private let directory: URL

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func write(_ data: Data, for traceID: UUID) throws {
        try data.write(to: url(for: traceID), options: .atomic)
    }

    public func load(traceID: UUID) throws -> Data {
        try Data(contentsOf: url(for: traceID), options: .mappedIfSafe)
    }

    public func exists(traceID: UUID) -> Bool {
        FileManager.default.fileExists(atPath: url(for: traceID).path)
    }

    public func size(traceID: UUID) -> Int? {
        let path = url(for: traceID).path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { return nil }
        return attrs[.size] as? Int
    }

    public func delete(traceID: UUID) {
        try? FileManager.default.removeItem(at: url(for: traceID))
    }

    public func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func url(for traceID: UUID) -> URL {
        directory.appendingPathComponent("\(traceID.uuidString).bin")
    }
}
