import Foundation

// MARK: - Terminal UI Implementation

@available(macOS 26.0, *)
final class TerminalUI: UserInterface {

    func status(_ message: String) {
        print(message)
    }
}