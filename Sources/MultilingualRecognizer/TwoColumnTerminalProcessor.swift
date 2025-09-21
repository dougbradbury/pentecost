import Foundation

@available(macOS 26.0, *)
final class TwoColumnTerminalProcessor: @unchecked Sendable, SpeechProcessor {
    private var englishLines: [String] = []
    private var frenchLines: [String] = []
    private let terminalWidth: Int
    private let columnWidth: Int
    private let leftMargin = 0
    private var rightMargin: Int { leftMargin + columnWidth + 2 } // +2 for separator

    init(terminalWidth: Int = 120) {
        self.terminalWidth = terminalWidth
        self.columnWidth = (terminalWidth - 4) / 2  // -4 for separator and margins
    }

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String) async {
        let flag = flagForLocale(locale)
        let timestamp = String(format: "%.1f", startTime)
        let status = isFinal ? "✅" : "⏳"
        let formattedText = "\(status) \(flag) [\(timestamp)s] \(text)"

        switch locale {
        case "en-US", "en":
            await updateEnglishColumn(formattedText, isFinal: isFinal)
        case "fr-FR", "fr":
            await updateFrenchColumn(formattedText, isFinal: isFinal)
        default:
            break
        }
    }

    private func updateEnglishColumn(_ text: String, isFinal: Bool) async {
        if isFinal {
            englishLines.append(text)
        } else {
            // Update the last line for partial results
            if !englishLines.isEmpty && englishLines.last?.contains("⏳") == true {
                englishLines[englishLines.count - 1] = text
            } else {
                englishLines.append(text)
            }
        }
        await redrawColumns()
    }

    private func updateFrenchColumn(_ text: String, isFinal: Bool) async {
        if isFinal {
            frenchLines.append(text)
        } else {
            // Update the last line for partial results
            if !frenchLines.isEmpty && frenchLines.last?.contains("⏳") == true {
                frenchLines[frenchLines.count - 1] = text
            } else {
                frenchLines.append(text)
            }
        }
        await redrawColumns()
    }

    private func redrawColumns() async {
        // Clear screen and move cursor to top
        print("\u{001B}[2J\u{001B}[H", terminator: "")

        // Print header
        let header = createHeader()
        print(header)
        print(String(repeating: "─", count: terminalWidth))

        // Get wrapped lines for both columns
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

    private func flagForLocale(_ locale: String) -> String {
        switch locale {
        case "en-US", "en": return "🇺🇸"
        case "fr-FR", "fr": return "🇫🇷"
        default: return "🌍"
        }
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