import Foundation

@available(macOS 26.0, *)
actor BroadcastProcessor: SpeechProcessor {
    private let processors: [SpeechProcessor]
    private var hasShutdown = false

    init(processors: [SpeechProcessor]) {
        self.processors = processors
    }

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String, source: String) async {
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
                        locale: locale,
                        source: source
                    )
                }
            }
        }
    }

    func shutdown() async {
        // Make shutdown idempotent - only run once even if called multiple times
        guard !hasShutdown else { return }
        hasShutdown = true

        // Shutdown all processors in parallel
        await withTaskGroup(of: Void.self) { group in
            for processor in processors {
                group.addTask {
                    await processor.shutdown()
                }
            }
        }
    }
}