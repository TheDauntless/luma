import Foundation
import GRDB

public struct CustomInstrumentDef: Codable, Identifiable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "custom_instrument_def"

    public var id: UUID
    public var name: String
    public var iconSystemName: String
    public var source: String
    public var features: [Feature]
    public var createdAt: Date
    public var updatedAt: Date

    public struct Feature: Codable, Identifiable, Sendable, Equatable {
        public var id: String
        public var name: String
        public var schema: FeatureSchema
        public var optional: Bool
        public var enabledByDefault: Bool

        public init(
            id: String,
            name: String,
            schema: FeatureSchema = .boolean,
            optional: Bool = true,
            enabledByDefault: Bool = true
        ) {
            self.id = id
            self.name = name
            self.schema = schema
            self.optional = optional
            self.enabledByDefault = enabledByDefault
        }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        iconSystemName: String = "wand.and.stars",
        source: String = CustomInstrumentDef.exampleSource,
        features: [Feature] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.source = source
        self.features = features
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(row: Row) throws {
        id = UUID(uuidString: row["id"])!
        name = row["name"]
        iconSystemName = row["icon_system_name"]
        source = row["source"]
        let featuresJSON: String = row["features_json"]
        features = try JSONDecoder().decode([Feature].self, from: Data(featuresJSON.utf8))
        createdAt = row["created_at"]
        updatedAt = row["updated_at"]
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id.uuidString
        container["name"] = name
        container["icon_system_name"] = iconSystemName
        container["source"] = source
        container["features_json"] = featuresJSONString
        container["created_at"] = createdAt
        container["updated_at"] = updatedAt
    }

    public func toJSON() -> [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "icon_system_name": iconSystemName,
            "source": source,
            "features": features.map(featureToJSON),
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt),
        ]
    }

    public static func fromJSON(_ obj: [String: Any]) -> CustomInstrumentDef? {
        guard let idStr = obj["id"] as? String, let id = UUID(uuidString: idStr),
            let name = obj["name"] as? String,
            let icon = obj["icon_system_name"] as? String,
            let source = obj["source"] as? String
        else { return nil }
        let features = parseFeatures(obj["features"])
        let isoFmt = ISO8601DateFormatter()
        let createdAt = (obj["created_at"] as? String).flatMap(isoFmt.date(from:)) ?? Date()
        let updatedAt = (obj["updated_at"] as? String).flatMap(isoFmt.date(from:)) ?? Date()
        return CustomInstrumentDef(
            id: id,
            name: name,
            iconSystemName: icon,
            source: source,
            features: features,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private var featuresJSONString: String {
        let data = try! JSONEncoder().encode(features)
        return String(decoding: data, as: UTF8.self)
    }

    private static func parseFeatures(_ raw: Any?) -> [Feature] {
        guard let arr = raw as? [[String: Any]] else { return [] }
        return arr.compactMap(parseFeature)
    }

    private static func parseFeature(_ obj: [String: Any]) -> Feature? {
        guard let id = obj["id"] as? String, let name = obj["name"] as? String else { return nil }
        let schema = parseFeatureSchema(obj["schema"]) ?? .boolean
        let enabledByDefault = (obj["enabled_by_default"] as? Bool) ?? true
        return Feature(id: id, name: name, schema: schema, enabledByDefault: enabledByDefault)
    }

    private static func parseFeatureSchema(_ raw: Any?) -> FeatureSchema? {
        guard let obj = raw as? [String: Any] else { return nil }
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: obj)
        } catch {
            return nil
        }
        return try? JSONDecoder().decode(FeatureSchema.self, from: data)
    }

    private func featureToJSON(_ feature: Feature) -> [String: Any] {
        var out: [String: Any] = [
            "id": feature.id,
            "name": feature.name,
            "enabled_by_default": feature.enabledByDefault,
        ]
        if let data = try? JSONEncoder().encode(feature.schema),
            let schemaObj = try? JSONSerialization.jsonObject(with: data)
        {
            out["schema"] = schemaObj
        }
        return out
    }

    public mutating func normalize() {
        for i in features.indices {
            features[i].schema = CustomInstrumentDef.normalizedSchema(features[i].schema)
            if case .boolean = features[i].schema, features[i].optional {
                features[i].optional = false
            }
        }
    }

    private static func normalizedSchema(_ schema: FeatureSchema) -> FeatureSchema {
        switch schema {
        case .object(let fields):
            return .object(fields: fields.map(normalizedField))
        case .array(let item, let d):
            return .array(item: normalizedArrayItem(item), default: d)
        default:
            return schema
        }
    }

    private static func normalizedField(_ field: ObjectField) -> ObjectField {
        var copy = field
        copy.schema = normalizedSchema(field.schema)
        if case .boolean = copy.schema, copy.optional {
            copy.optional = false
        }
        return copy
    }

    private static func normalizedArrayItem(_ item: ArrayItemSchema) -> ArrayItemSchema {
        switch item {
        case .object(let fields):
            return .object(fields: fields.map(normalizedField))
        default:
            return item
        }
    }

    public static let exampleSource: String = """
        // A custom instrument is a regular Frida agent module. It runs in
        // the target process and exports an `instrument` object that the
        // host loads via the standard instrument lifecycle.
        //
        // create():  install your hooks; return updateConfig + dispose.
        // dispose(): undo every side effect (detach listeners, revert
        //            replacements). Save will call this and then re-create
        //            with the new source.
        //
        // Features you declare in the sidebar show up on `config.features`
        // typed exactly as you defined them. Accessing a feature you have
        // not declared is a type error. The boilerplate below uses one
        // feature called `logStack`; it is commented out until you add it
        // (right-click the instrument → Features… → Add `logStack`,
        // schema: Boolean).

        export const instrument: CustomInstrument = {
            create(ctx, config) {
                let current = config;
                const listeners: InvocationListener[] = [];

                const open = Module.findGlobalExportByName("open");
                if (open !== null) {
                    listeners.push(Interceptor.attach(open, {
                        onEnter(args) {
                            ctx.emit({ syscall: "open", path: args[0].readUtf8String() });
                            // if (current.features.logStack) {
                            //     ctx.emit({ stack: this.context.sp.readByteArray(64) });
                            // }
                        }
                    }));
                }

                return {
                    updateConfig(next) {
                        current = next;
                    },
                    dispose() {
                        for (const l of listeners) {
                            l.detach();
                        }
                    }
                };
            }
        };
        """
}
