import Foundation
import NaturalLanguage

@available(macOS 26.0, *)
final class LanguageFilterProcessor: SpeechProcessor {
    private let nextProcessor: SpeechProcessor
    private let confidenceThreshold: Float

    init(nextProcessor: SpeechProcessor, confidenceThreshold: Float = 0.7) {
        self.nextProcessor = nextProcessor
        self.confidenceThreshold = confidenceThreshold
    }

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String, source: String) async {
        // Only filter final results - let partial results through for real-time feedback
        guard isFinal else {
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

        // Skip filtering if text is too short for reliable detection
        guard text.count >= 10 else {
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

        // Detect dominant language using NaturalLanguage framework
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let dominantLanguage = recognizer.dominantLanguage else {
            // If we can't detect language, pass through
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

        // Get confidence score for the dominant language
        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)
        let confidence = hypotheses[dominantLanguage] ?? 0.0

        // Map NaturalLanguage codes to our locale codes
        let expectedLanguage = expectedLanguageForLocale(locale)
        let detectedLanguage = dominantLanguage.rawValue

        // Check if detected language matches the recognizer's locale
        let isLanguageMatch = isLanguageCompatible(detected: detectedLanguage, expected: expectedLanguage)

        // Only pass through if language matches and confidence is high enough
        if isLanguageMatch && Float(confidence) >= confidenceThreshold {
            await nextProcessor.process(
                text: text,
                isFinal: isFinal,
                startTime: startTime,
                duration: duration,
                alternativeCount: alternativeCount,
                locale: locale,
                source: source
            )
        } else {
            // Filter out mismatched results - silently ignore
        }
    }

    private func expectedLanguageForLocale(_ locale: String) -> String {
        switch locale {
        case "en-US", "en":
            return "en"
        case "fr-CA", "fr":
            return "fr"
        default:
            return locale
        }
    }

    private func isLanguageCompatible(detected: String, expected: String) -> Bool {
        // Handle language code variations
        let normalizedDetected = detected.lowercased()
        let normalizedExpected = expected.lowercased()

        // Direct match
        if normalizedDetected == normalizedExpected {
            return true
        }

        // Handle common variations
        switch (normalizedDetected, normalizedExpected) {
        case ("en", "en-us"), ("en-us", "en"):
            return true
        case ("fr", "fr-fr"), ("fr-fr", "fr"):
            return true
        default:
            return false
        }
    }

    func shutdown() async {
        // Propagate shutdown to next processor
        await nextProcessor.shutdown()
    }
}