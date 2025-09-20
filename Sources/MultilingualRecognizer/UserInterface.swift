import Foundation

// MARK: - Terminal UI Implementation

@available(macOS 26.0, *)
final class TerminalUI: @unchecked Sendable, UserInterface {

    func status(_ message: String) {
        print(message)
    }

    func displayResult(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String) {
        let flag = flagForLocale(locale)

        if isFinal {
            // Clear the line and print final result permanently with timing
            print("\r\u{001B}[2K✅ \(flag) FINAL: \(text) [\(String(format: "%.1f", startTime))s-\(String(format: "%.1f", startTime + duration))s, \(alternativeCount) alt]")
            fflush(stdout)
        } else {
            // Overwrite current line for partial results with timing
            print("\r⏳ \(flag) PARTIAL: \(text) [\(String(format: "%.1f", startTime))s]", terminator: "")
            fflush(stdout)
        }
    }

    private func flagForLocale(_ locale: String) -> String {
        switch locale {
        case "en-US", "en":
            return "🇺🇸"
        case "fr-FR", "fr":
            return "🇫🇷"
        default:
            return "🌐"
        }
    }
}