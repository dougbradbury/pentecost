import Foundation

public protocol SpeechProcessor: Sendable {
    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String) async
}