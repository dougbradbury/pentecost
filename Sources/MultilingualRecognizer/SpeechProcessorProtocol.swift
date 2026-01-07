import Foundation

protocol SpeechProcessor: Sendable {
    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String, source: String) async
}