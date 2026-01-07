import Foundation

@available(macOS 26.0, *)
actor MessageBuffer {
    private var messages: [SpeechMessage] = []

    func updateMessage(text: String, isFinal: Bool, startTime: Double, duration: Double, locale: String, source: String) {
        // Strategy 1: Look for existing message with similar startTime (0.1s tolerance)
        if let index = messages.firstIndex(where: { abs($0.startTime - startTime) < 0.1 }) {
            // Update existing message found by time
            messages[index].text = text
            messages[index].isFinal = isFinal
            messages[index].duration = duration
            // Note: Keep original startTime for time-matched updates
            return
        }

        // Strategy 2: For pending messages, check if there's an existing pending message with same text
        // that needs time correction (handles phantom detections that get corrected)
        if !isFinal {
            if let index = messages.firstIndex(where: { !$0.isFinal && $0.text == text }) {
                // Found an existing pending message with same text - update it with new timing
                messages[index].startTime = startTime
                messages[index].isFinal = isFinal
                messages[index].duration = duration
                // Re-sort since startTime changed
                messages.sort { $0.startTime < $1.startTime }
                return
            }
        }

        // Strategy 3: Check if new message overlaps with any existing pending message's time range
        // (handles expanding text scenarios)
        let newEndTime = startTime + duration
        if let index = messages.firstIndex(where: { !$0.isFinal &&
            (startTime < $0.endTime && newEndTime > $0.startTime) }) {
            // Found a pending message that this new message overlaps with - replace it
            messages[index].startTime = startTime
            messages[index].text = text
            messages[index].isFinal = isFinal
            messages[index].duration = duration
            // Re-sort since startTime may have changed
            messages.sort { $0.startTime < $1.startTime }
            return
        }

        // Strategy 4: No existing message found, create new one
        let message = SpeechMessage(
            startTime: startTime,
            text: text,
            isFinal: isFinal,
            duration: duration,
            locale: locale,
            source: source
        )
        messages.append(message)
        // Sort by startTime to maintain chronological order
        messages.sort { $0.startTime < $1.startTime }
    }

    func getMessages() -> [SpeechMessage] {
        return messages
    }

    func clearMessages() {
        messages.removeAll()
    }
}