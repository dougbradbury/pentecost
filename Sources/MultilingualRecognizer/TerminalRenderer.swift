import Foundation

@available(macOS 26.0, *)
final class TerminalRenderer: @unchecked Sendable {
    private let terminalWidth: Int
    private let columnWidth: Int
    private let leftMargin = 0
    private var rightMargin: Int { leftMargin + columnWidth + 2 } // +2 for separator

    init(terminalWidth: Int = 120) {
        self.terminalWidth = terminalWidth
        self.columnWidth = (terminalWidth - 4) / 2  // -4 for separator and margins
    }

    func render(englishMessages: [SpeechMessage], frenchMessages: [SpeechMessage]) {
        // Clear screen and move cursor to top
        print("\u{001B}[2J\u{001B}[H", terminator: "")

        // Print header
        let header = createHeader()
        print(header)
        print(String(repeating: "─", count: terminalWidth))

        // Get wrapped lines for both columns with proper formatting
        let wrappedEnglish = englishMessages.flatMap { $0.formatForColumn(width: columnWidth) }
        let wrappedFrench = frenchMessages.flatMap { $0.formatForColumn(width: columnWidth) }

        // Print columns side by side
        let maxLines = max(wrappedEnglish.count, wrappedFrench.count)
        for i in 0..<maxLines {
            let englishLine = i < wrappedEnglish.count ? wrappedEnglish[i] : ""
            let frenchLine = i < wrappedFrench.count ? wrappedFrench[i] : ""

            // Pad each line to exact column width, accounting for emoji visual width
            let leftColumn = formatColumnText(englishLine, width: columnWidth)
            let rightColumn = formatColumnText(frenchLine, width: columnWidth)

            print("\(leftColumn) │ \(rightColumn)")
        }

        fflush(stdout)
    }

    private func createHeader() -> String {
        let englishHeader = "ENGLISH".padding(toLength: columnWidth, withPad: " ", startingAt: 0)
        let frenchHeader = "FRENCH".padding(toLength: columnWidth, withPad: " ", startingAt: 0)
        return "\(englishHeader) │ \(frenchHeader)"
    }

    private func formatColumnText(_ text: String, width: Int) -> String {
        return TextUtils.formatColumn(text, width: width)
    }
}