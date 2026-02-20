import Foundation

@available(macOS 26.0, *)
final class MinimumLengthFilterProcessor: SpeechProcessor {
    private let nextProcessor: SpeechProcessor
    private let minimumWordCount: Int

    /// Creates a minimum length filter processor that only passes results with sufficient word count
    /// - Parameters:
    ///   - nextProcessor: The next processor in the chain
    ///   - minimumWordCount: Minimum number of words for partial results to pass through (default 5)
    init(nextProcessor: SpeechProcessor, minimumWordCount: Int = 5) {
        self.nextProcessor = nextProcessor
        self.minimumWordCount = minimumWordCount
    }

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String, source: String) async {
        // Always pass through final results regardless of length
        if isFinal {
            await nextProcessor.process(
                text: text,
                isFinal: isFinal,
                startTime: startTime,
                duration: duration,
                alternativeCount: alternativeCount,
                locale: locale,
                source: source
            )
            return
        }

        // For partial results, check word count
        let wordCount = countWords(in: text)

        // Only pass through partial results with sufficient word count
        if wordCount >= minimumWordCount {
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
        // Otherwise, silently filter out short partial results
    }

    /// Count words in text, handling multiple whitespace types
    private func countWords(in text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        // Split by whitespace and filter out empty strings
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        return words.count
    }
}
