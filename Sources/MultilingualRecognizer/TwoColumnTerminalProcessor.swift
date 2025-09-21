import Foundation

struct SpeechMessage {
    let startTime: Double
    var text: String
    var isFinal: Bool
    var duration: Double
    let locale: String

    func formatForColumn(width: Int) -> [String] {
        let timestamp = String(format: "%5.1f", startTime)

        // Color codes for status indication
        let brightWhite = "\u{001B}[97m"  // Bright white for final
        let dimGray = "\u{001B}[90m"      // Dim gray for pending
        let reset = "\u{001B}[0m"         // Reset color

        let colorCode = isFinal ? brightWhite : dimGray
        let prefix = "\(timestamp)s "

        // Calculate the exact prefix length for proper alignment
        let prefixLength = prefix.count
        let textWidth = width - prefixLength

        if textWidth <= 10 { // Minimum text width
            return [prefix + "\(colorCode)\(text)\(reset)"]
        }

        // Wrap the text content (without color codes for accurate length calculation)
        let wrappedText = TextUtils.wrapText(text, width: textWidth)
        var result: [String] = []

        for (index, line) in wrappedText.enumerated() {
            if index == 0 {
                // First line: timestamp + colored text
                result.append(prefix + "\(colorCode)\(line)\(reset)")
            } else {
                // Continuation lines: indent to match text start position + colored text
                let indent = String(repeating: " ", count: prefixLength)
                result.append(indent + "\(colorCode)\(line)\(reset)")
            }
        }

        return result
    }

}

@available(macOS 26.0, *)
final class TwoColumnTerminalProcessor: @unchecked Sendable, SpeechProcessor {
    private var englishMessages: [SpeechMessage] = []
    private var frenchMessages: [SpeechMessage] = []
    private let terminalWidth: Int
    private let columnWidth: Int
    private let leftMargin = 0
    private var rightMargin: Int { leftMargin + columnWidth + 2 } // +2 for separator

    init(terminalWidth: Int = 120) {
        self.terminalWidth = terminalWidth
        self.columnWidth = (terminalWidth - 4) / 2  // -4 for separator and margins
    }

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String) async {
        switch locale {
        case "en-US", "en":
            await updateEnglishMessages(text: text, isFinal: isFinal, startTime: startTime, duration: duration, locale: locale)
        case "fr-FR", "fr":
            await updateFrenchMessages(text: text, isFinal: isFinal, startTime: startTime, duration: duration, locale: locale)
        default:
            break
        }
        await redrawColumns()
    }

    private func updateEnglishMessages(text: String, isFinal: Bool, startTime: Double, duration: Double, locale: String) async {
        // Look for existing message with this startTime
        if let index = englishMessages.firstIndex(where: { abs($0.startTime - startTime) < 0.1 }) {
            // Update existing message
            englishMessages[index].text = text
            englishMessages[index].isFinal = isFinal
            englishMessages[index].duration = duration
        } else {
            // Create new message
            let message = SpeechMessage(
                startTime: startTime,
                text: text,
                isFinal: isFinal,
                duration: duration,
                locale: locale
            )
            englishMessages.append(message)
            // Sort by startTime to maintain chronological order
            englishMessages.sort { $0.startTime < $1.startTime }
        }
    }

    private func updateFrenchMessages(text: String, isFinal: Bool, startTime: Double, duration: Double, locale: String) async {
        // Look for existing message with this startTime
        if let index = frenchMessages.firstIndex(where: { abs($0.startTime - startTime) < 0.1 }) {
            // Update existing message
            frenchMessages[index].text = text
            frenchMessages[index].isFinal = isFinal
            frenchMessages[index].duration = duration
        } else {
            // Create new message
            let message = SpeechMessage(
                startTime: startTime,
                text: text,
                isFinal: isFinal,
                duration: duration,
                locale: locale
            )
            frenchMessages.append(message)
            // Sort by startTime to maintain chronological order
            frenchMessages.sort { $0.startTime < $1.startTime }
        }
    }

    private func redrawColumns() async {
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

