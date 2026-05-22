import Foundation

public enum LumaCoreError: LocalizedError {
    case invalidArgument(String)
    case invalidOperation(String)
    case protocolViolation(String)
    case notSupported(String)

    public var errorDescription: String? {
        switch self {
        case .invalidArgument(let message),
             .invalidOperation(let message),
             .protocolViolation(let message),
             .notSupported(let message):
            return message
        }
    }
}
