import Foundation

// MARK: - UI Protocol

protocol UserInterface: Sendable {
    func status(_ message: String)
    func displayResult(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String)
}