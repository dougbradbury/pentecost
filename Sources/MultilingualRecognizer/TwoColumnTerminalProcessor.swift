import Foundation

struct SpeechMessage {
    var startTime: Double
    var text: String
    var isFinal: Bool
    var duration: Double
    let locale: String

    var endTime: Double {
        return startTime + duration
    }

    func formatForColumn(width: Int) -> [String] {
        let timestamp = String(format: "%5.1f", startTime)
        let statusEmoji = isFinal ? "x" : "?"
        let prefix = "\(timestamp)s \(statusEmoji) "

        // Calculate the exact prefix length for proper alignment
        let prefixLength = prefix.count
        let textWidth = width - prefixLength

        if textWidth <= 10 { // Minimum text width
            return [prefix + text]
        }

        // Wrap the text content
        let wrappedText = TextUtils.wrapText(text, width: textWidth)
        var result: [String] = []

        for (index, line) in wrappedText.enumerated() {
            if index == 0 {
                // First line: timestamp + emoji + text
                result.append(prefix + line)
            } else {
                // Continuation lines: indent to match text start position
                let indent = String(repeating: " ", count: prefixLength)
                result.append(indent + line)
            }
        }

        return result
    }

}

@available(macOS 26.0, *)
final class TwoColumnTerminalProcessor: @unchecked Sendable, SpeechProcessor {
    private let englishBuffer: MessageBuffer
    private let frenchBuffer: MessageBuffer
    private let terminalRenderer: TerminalRenderer

    init(terminalWidth: Int = 120) {
        self.englishBuffer = MessageBuffer()
        self.frenchBuffer = MessageBuffer()
        self.terminalRenderer = TerminalRenderer(terminalWidth: terminalWidth)
    }

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String) async {
        switch locale {
        case "en-US", "en":
            englishBuffer.updateMessage(text: text, isFinal: isFinal, startTime: startTime, duration: duration, locale: locale)
        case "fr-FR", "fr":
            frenchBuffer.updateMessage(text: text, isFinal: isFinal, startTime: startTime, duration: duration, locale: locale)
        default:
            break
        }
        await render()
    }

    private func render() async {
        let englishMessages = englishBuffer.getMessages()
        let frenchMessages = frenchBuffer.getMessages()
        terminalRenderer.render(englishMessages: englishMessages, frenchMessages: frenchMessages)
    }
}

