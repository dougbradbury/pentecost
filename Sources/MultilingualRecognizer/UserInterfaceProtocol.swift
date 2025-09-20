import Foundation

// MARK: - UI Protocol

protocol UserInterface: Sendable {
    func status(_ message: String)
}