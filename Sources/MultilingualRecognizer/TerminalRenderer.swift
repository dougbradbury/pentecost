import Foundation
import Darwin

@available(macOS 26.0, *)
final class TerminalRenderer: @unchecked Sendable {
    private let leftMargin = 0

    // Dynamically calculate terminal width
    private var terminalWidth: Int {
        return getTerminalWidth()
    }

    // Dynamically calculate column width based on current terminal width
    private var columnWidth: Int {
        return (terminalWidth - 4) / 2  // -4 for separator and margins
    }

    private var rightMargin: Int { leftMargin + columnWidth + 2 } // +2 for separator

    init() {
        // No longer need fixed width parameter
    }

    // Dynamically calculate max display lines based on terminal height
    private var maxDisplayLines: Int {
        let terminalHeight = getTerminalHeight()
        // Reserve 3 lines for header, separator, and bottom margin
        return max(5, terminalHeight - 3)
    }

    private func getTerminalHeight() -> Int {
        var winsize = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &winsize) == 0 {
            return Int(winsize.ws_row)
        }
        return 25 // fallback if detection fails
    }

    private func getTerminalWidth() -> Int {
        var winsize = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &winsize) == 0 {
            return Int(winsize.ws_col)
        }
        return 120 // fallback if detection fails
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

        // Print columns side by side, limiting total lines to prevent flickering
        let maxLines = max(wrappedEnglish.count, wrappedFrench.count)
        let displayLines = min(maxLines, maxDisplayLines)

        // Calculate offset to show the most recent lines
        let englishOffset = max(0, wrappedEnglish.count - displayLines)
        let frenchOffset = max(0, wrappedFrench.count - displayLines)

        for i in 0..<displayLines {
            let englishIndex = englishOffset + i
            let frenchIndex = frenchOffset + i

            let englishLine = englishIndex < wrappedEnglish.count ? wrappedEnglish[englishIndex] : ""
            let frenchLine = frenchIndex < wrappedFrench.count ? wrappedFrench[frenchIndex] : ""

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
