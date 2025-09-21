import Foundation

struct SpeechMessage {
    let startTime: Double
    var text: String
    var isFinal: Bool
    var duration: Double
    let locale: String

    var formattedText: String {
        let flag = flagForLocale(locale)
        let status = isFinal ? "✅" : "⏳"
        let timestamp = String(format: "%.1f", startTime)
        return "\(status) \(flag) [\(timestamp)s] \(text)"
    }

    private func flagForLocale(_ locale: String) -> String {
        switch locale {
        case "en-US", "en": return "🇺🇸"
        case "fr-FR", "fr": return "🇫🇷"
        default: return "🌍"
        }
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

        // Get wrapped lines for both columns
        let englishLines = englishMessages.map { $0.formattedText }
        let frenchLines = frenchMessages.map { $0.formattedText }
        let wrappedEnglish = wrapLines(englishLines)
        let wrappedFrench = wrapLines(frenchLines)

        // Print columns side by side
        let maxLines = max(wrappedEnglish.count, wrappedFrench.count)
        for i in 0..<maxLines {
            let englishLine = i < wrappedEnglish.count ? wrappedEnglish[i] : ""
            let frenchLine = i < wrappedFrench.count ? wrappedFrench[i] : ""

            let leftColumn = formatColumnText(englishLine, width: columnWidth)
            let rightColumn = formatColumnText(frenchLine, width: columnWidth)

            print("\(leftColumn) │ \(rightColumn)")
        }

        fflush(stdout)
    }

    private func createHeader() -> String {
        let englishHeader = "🇺🇸 ENGLISH".padding(toLength: columnWidth, withPad: " ", startingAt: 0)
        let frenchHeader = "🇫🇷 FRENCH".padding(toLength: columnWidth, withPad: " ", startingAt: 0)
        return "\(englishHeader) │ \(frenchHeader)"
    }

    private func wrapLines(_ lines: [String]) -> [String] {
        var wrappedLines: [String] = []
        for line in lines {
            let wrapped = wrapText(line, width: columnWidth)
            wrappedLines.append(contentsOf: wrapped)
        }
        return wrappedLines
    }

    private func wrapText(_ text: String, width: Int) -> [String] {
        if text.count <= width {
            return [text]
        }

        var lines: [String] = []
        var currentLine = ""
        let words = text.split(separator: " ")

        for word in words {
            let wordStr = String(word)
            if currentLine.count + wordStr.count + 1 <= width {
                if currentLine.isEmpty {
                    currentLine = wordStr
                } else {
                    currentLine += " " + wordStr
                }
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                    currentLine = wordStr
                } else {
                    // Word is longer than width, split it
                    let chunks = wordStr.chunked(into: width)
                    lines.append(contentsOf: chunks.dropLast())
                    currentLine = chunks.last ?? ""
                }
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines.isEmpty ? [""] : lines
    }

    private func formatColumnText(_ text: String, width: Int) -> String {
        return text.padding(toLength: width, withPad: " ", startingAt: 0)
    }
}

extension String {
    func chunked(into size: Int) -> [String] {
        return stride(from: 0, to: self.count, by: size).map {
            let start = self.index(self.startIndex, offsetBy: $0)
            let end = self.index(start, offsetBy: min(size, self.count - $0))
            return String(self[start..<end])
        }
    }
}