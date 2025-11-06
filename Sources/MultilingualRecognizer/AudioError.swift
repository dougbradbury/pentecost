import Foundation

public enum AudioError: Error {
    case formatError(String)
    case deviceError(String)
}
