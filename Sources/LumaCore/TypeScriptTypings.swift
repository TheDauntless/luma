public struct TypeScriptTypingFile: Sendable, Equatable {
    public let filePath: String
    public let content: String

    public init(filePath: String, content: String) {
        self.filePath = filePath
        self.content = content
    }
}

public enum TypeScriptTypings {
    public static var fridaGum: [TypeScriptTypingFile] { LumaTypings.fridaGum }
    public static var node: [TypeScriptTypingFile] { LumaTypings.node }
}
