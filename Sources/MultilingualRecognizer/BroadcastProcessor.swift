import Foundation

@available(macOS 26.0, *)
final class BroadcastProcessor: @unchecked Sendable, SpeechProcessor {
    private let processors: [SpeechProcessor]

    init(processors: [SpeechProcessor]) {
        self.processors = processors
    }

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String) async {
        // Process messages in parallel using TaskGroup
        await withTaskGroup(of: Void.self) { group in
            for processor in processors {
                group.addTask {
                    await processor.process(
                        text: text,
                        isFinal: isFinal,
                        startTime: startTime,
                        duration: duration,
                        alternativeCount: alternativeCount,
                        locale: locale
                    )
                }
            }
        }
    }
}