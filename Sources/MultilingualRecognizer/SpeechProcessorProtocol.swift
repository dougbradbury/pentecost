import Foundation

protocol SpeechProcessor: Sendable {
    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String, source: String) async

    /// Called during shutdown to allow the processor to clean up resources
    /// Default implementation does nothing
    func shutdown() async
}

extension SpeechProcessor {
    func shutdown() async {
        // Default implementation - no cleanup needed
    }
}