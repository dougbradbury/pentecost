import Foundation

// MARK: - UI Protocol

public protocol UserInterface: Sendable {
    func status(_ message: String)
}