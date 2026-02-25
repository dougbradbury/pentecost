import Foundation
import Translation

@available(macOS 26.0, *)
final class TranslationProcessor: SpeechProcessor {
    private let nextProcessor: SpeechProcessor
    private let minimumWordCount: Int
    private let taskTracker = TranslationTaskTracker()

    /// Creates a translation processor
    /// - Parameters:
    ///   - nextProcessor: The next processor in the chain
    ///   - minimumWordCount: Minimum words required to translate partial results (default 5)
    init(nextProcessor: SpeechProcessor, minimumWordCount: Int = 5) {
        self.nextProcessor = nextProcessor
        self.minimumWordCount = minimumWordCount
    }

    func shutdown() async {
        // Wait for all pending translations to complete
        await taskTracker.waitForAll()
        // Propagate shutdown to next processor in chain
        await nextProcessor.shutdown()
    }

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String, source: String) async {
        // Always pass through the original result
        await nextProcessor.process(
            text: text,
            isFinal: isFinal,
            startTime: startTime,
            duration: duration,
            alternativeCount: alternativeCount,
            locale: locale,
            source: source
        )

        // Translate final results OR partial results with enough words
        let shouldTranslate: Bool
        if isFinal {
            shouldTranslate = true
        } else {
            // Count words for partial results
            let wordCount = countWords(in: text)
            shouldTranslate = wordCount >= minimumWordCount
        }

        guard shouldTranslate else { return }

        // Determine target language
        let targetLocale: String
        let sourceLanguage: Locale.Language
        let targetLanguage: Locale.Language

        switch locale {
        case "en-US", "en":
            targetLocale = "fr-CA"
            sourceLanguage = Locale.Language(identifier: "en")
            targetLanguage = Locale.Language(identifier: "fr")
        case "fr-CA", "fr":
            targetLocale = "en-US"
            sourceLanguage = Locale.Language(identifier: "fr")
            targetLanguage = Locale.Language(identifier: "en")
        default:
            return // Skip translation for unknown languages
        }

        // Create a tracked task for translation
        await taskTracker.addTask { [nextProcessor] in
            do {
                // Create session for this specific translation
                let session = TranslationSession(installedSource: sourceLanguage, target: targetLanguage)

                let response = try await session.translate(text)

                // Pass the translated result to the next processor with translation indicator
                await nextProcessor.process(
                    text: "🔄 \(response.targetText)",
                    isFinal: isFinal, // Preserve final/partial status
                    startTime: startTime,
                    duration: duration,
                    alternativeCount: 1, // Translation result has no alternatives
                    locale: targetLocale,
                    source: source
                )

            } catch {
                // Only print error if not cancelled
                if !(error is CancellationError) {
                    print("❌ Translation failed for \(locale) → \(targetLocale): \(error)")
                }
            }
        }
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

/// Actor to safely track pending translation tasks
@available(macOS 26.0, *)
private actor TranslationTaskTracker {
    private var pendingCount = 0

    func addTask(_ operation: @escaping @Sendable () async -> Void) {
        pendingCount += 1
        Task {
            await operation()
            await self.taskCompleted()
        }
    }

    private func taskCompleted() {
        pendingCount -= 1
    }

    func waitForAll() async {
        while pendingCount > 0 {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}