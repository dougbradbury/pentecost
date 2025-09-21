import Foundation
import Translation

@available(macOS 26.0, *)
final class TranslationProcessor: @unchecked Sendable, SpeechProcessor {
    private let nextProcessor: SpeechProcessor

    init(nextProcessor: SpeechProcessor) {
        self.nextProcessor = nextProcessor
    }

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String) async {
        // Always pass through the original result
        await nextProcessor.process(
            text: text,
            isFinal: isFinal,
            startTime: startTime,
            duration: duration,
            alternativeCount: alternativeCount,
            locale: locale
        )

        // Only translate final results
        guard isFinal else { return }

        // Determine target language
        let targetLocale: String
        let sourceLanguage: Locale.Language
        let targetLanguage: Locale.Language

        switch locale {
        case "en-US", "en":
            targetLocale = "fr-FR"
            sourceLanguage = Locale.Language(identifier: "en")
            targetLanguage = Locale.Language(identifier: "fr")
        case "fr-FR", "fr":
            targetLocale = "en-US"
            sourceLanguage = Locale.Language(identifier: "fr")
            targetLanguage = Locale.Language(identifier: "en")
        default:
            return // Skip translation for unknown languages
        }

        do {
            // Create session for this specific translation
            let session = TranslationSession(installedSource: sourceLanguage, target: targetLanguage)

            let response = try await session.translate(text)

            // Pass the translated result to the next processor with translation indicator
            await nextProcessor.process(
                text: "🔄 \(response.targetText)",
                isFinal: true,
                startTime: startTime,
                duration: duration,
                alternativeCount: 1, // Translation result has no alternatives
                locale: targetLocale
            )

        } catch {
            print("❌ Translation failed for \(locale) → \(targetLocale): \(error)")
        }
    }
}