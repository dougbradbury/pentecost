import Foundation

// MARK: - Terminal UI Implementation

@available(macOS 26.0, *)
final class TerminalUI: @unchecked Sendable, UserInterface {

    func status(_ message: String) {
        print(message)
    }
}