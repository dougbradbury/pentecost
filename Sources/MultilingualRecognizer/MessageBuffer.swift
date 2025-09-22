import Foundation

@available(macOS 26.0, *)
final class MessageBuffer: @unchecked Sendable {
    private var messages: [SpeechMessage] = []

    func updateMessage(text: String, isFinal: Bool, startTime: Double, duration: Double, locale: String) {
        // Look for existing message with this startTime
        if let index = messages.firstIndex(where: { abs($0.startTime - startTime) < 0.1 }) {
            // Update existing message
            messages[index].text = text
            messages[index].isFinal = isFinal
            messages[index].duration = duration
        } else {
            // Create new message
            let message = SpeechMessage(
                startTime: startTime,
                text: text,
                isFinal: isFinal,
                duration: duration,
                locale: locale
            )
            messages.append(message)
            // Sort by startTime to maintain chronological order
            messages.sort { $0.startTime < $1.startTime }
        }
    }

    func getMessages() -> [SpeechMessage] {
        return messages
    }

    func clearMessages() {
        messages.removeAll()
    }
}