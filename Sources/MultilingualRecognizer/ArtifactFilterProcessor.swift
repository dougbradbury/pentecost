import Foundation

@available(macOS 26.0, *)
final class ArtifactFilterProcessor: @unchecked Sendable, SpeechProcessor {
    private let nextProcessor: SpeechProcessor
    private let commaThreshold: Double
    private let repetitionThreshold: Int

    /// Creates an artifact filter processor that removes recognition artifacts from wrong language detection
    /// - Parameters:
    ///   - nextProcessor: The next processor in the chain
    ///   - commaThreshold: Minimum ratio of commas to text length to trigger filtering (default 0.5 = 50%)
    ///   - repetitionThreshold: Minimum number of word repetitions to trigger filtering (default 4)
    init(nextProcessor: SpeechProcessor, commaThreshold: Double = 0.5, repetitionThreshold: Int = 4) {
        self.nextProcessor = nextProcessor
        self.commaThreshold = commaThreshold
        self.repetitionThreshold = repetitionThreshold
    }

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String, source: String) async {
        // Check if the text is mostly commas and spaces
        let trimmedText = text.trimmingCharacters(in: .whitespaces)

        // Empty or whitespace-only text passes through
        guard !trimmedText.isEmpty else {
            return
        }

        // Count commas in the text
        let commaCount = text.filter { $0 == "," }.count
        let totalLength = trimmedText.count

        // Calculate comma ratio
        let commaRatio = Double(commaCount) / Double(totalLength)

        // Filter out if text is primarily commas (e.g., ", , , , , , ,")
        if commaRatio >= commaThreshold {
            // Silently filter - this is likely noise from wrong language detection
            return
        }

        // Also filter out text that is ONLY commas and spaces (regardless of ratio)
        let withoutCommasAndSpaces = text.filter { $0 != "," && $0 != " " }
        guard !withoutCommasAndSpaces.isEmpty else {
            // Text contains only commas and spaces - filter it out
            return
        }

        // Check for repetitive word patterns like ", no, no, no, no, no, no,"
        if hasExcessiveWordRepetition(text) {
            // Silently filter - this is likely noise from wrong language detection
            return
        }

        // Text looks valid, pass it through
        await nextProcessor.process(
            text: text,
            isFinal: isFinal,
            startTime: startTime,
            duration: duration,
            alternativeCount: alternativeCount,
            locale: locale,
            source: source
        )
    }

    /// Detects if text has excessive repetition of the same word
    /// Returns true if any word is repeated consecutively more than the threshold
    private func hasExcessiveWordRepetition(_ text: String) -> Bool {
        // Split text into words (comma-separated tokens)
        let components = text.components(separatedBy: ",")
        let words = components.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        // Need at least repetitionThreshold words to trigger
        guard words.count >= repetitionThreshold else {
            return false
        }

        // Count consecutive repetitions of each word
        var currentWord = ""
        var consecutiveCount = 0
        var maxConsecutiveCount = 0

        for word in words {
            if word == currentWord {
                consecutiveCount += 1
                maxConsecutiveCount = max(maxConsecutiveCount, consecutiveCount)
            } else {
                currentWord = word
                consecutiveCount = 1
            }
        }

        // Filter if we found a word repeated consecutively more than threshold times
        return maxConsecutiveCount >= repetitionThreshold
    }
}
