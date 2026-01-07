import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation

// MARK: - Speech Recognition

@available(macOS 26.0, *)
final class ProductionMultilingualRecognizer: @unchecked Sendable {
    private var inputSequence: AsyncStream<AnalyzerInput>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?

    // Multiple transcribers for different languages
    private var englishTranscriber: SpeechTranscriber?
    private var frenchTranscriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?

    private var recognitionTasks: [Task<(), Never>] = []
    private var converter = BufferConverter()
    private let ui: UserInterface
    private let speechProcessor: SpeechProcessor

    var analyzerFormat: AVAudioFormat?

    init(ui: UserInterface, speechProcessor: SpeechProcessor) {
        self.ui = ui
        self.speechProcessor = speechProcessor
    }

    func setUpMultilingualTranscriber() async throws {
        ui.status("🔧 Setting up multilingual transcribers...")

        // Create English transcriber
        englishTranscriber = SpeechTranscriber(
            locale: Locale(identifier: "en-US"),
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )

        // Create French transcriber
        frenchTranscriber = SpeechTranscriber(
            locale: Locale(identifier: "fr-FR"),
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )

        guard let englishTranscriber, let frenchTranscriber else {
            throw NSError(domain: "TranscriptionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to setup transcribers"])
        }

        ui.status("✅ English transcriber created (en-US)")
        ui.status("✅ French transcriber created (fr-FR)")

        // Create SpeechAnalyzer with both transcribers for automatic language detection
        analyzer = SpeechAnalyzer(modules: [englishTranscriber, frenchTranscriber])
        ui.status("✅ SpeechAnalyzer created with multilingual support")

        // Get the best audio format for both transcribers
        self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [englishTranscriber, frenchTranscriber])
        ui.status("🎤 Optimal audio format: \(analyzerFormat?.description ?? "Unknown")")

        // Create input stream
        (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

        guard let inputSequence else { return }

        // Start recognition tasks for both languages - process results directly
        let ui = self.ui
        let processor = self.speechProcessor
        let englishTask = Task { @Sendable in
            do {
                for try await case let result in englishTranscriber.results {
                    let text = String(result.text.characters)
                    let startTime = CMTimeGetSeconds(result.range.start)
                    let duration = CMTimeGetSeconds(result.range.duration)
                    await processor.process(
                        text: text,
                        isFinal: result.isFinal,
                        startTime: startTime,
                        duration: duration,
                        alternativeCount: result.alternatives.count,
                        locale: "en-US",
                        source: "unknown"
                    )
                }
            } catch {
                ui.status("❌ English recognition failed: \(error)")
            }
        }

        let frenchTask = Task { @Sendable in
            do {
                for try await case let result in frenchTranscriber.results {
                    let text = String(result.text.characters)
                    let startTime = CMTimeGetSeconds(result.range.start)
                    let duration = CMTimeGetSeconds(result.range.duration)
                    await processor.process(
                        text: text,
                        isFinal: result.isFinal,
                        startTime: startTime,
                        duration: duration,
                        alternativeCount: result.alternatives.count,
                        locale: "fr-FR",
                        source: "unknown"
                    )
                }
            } catch {
                ui.status("❌ French recognition failed: \(error)")
            }
        }

        recognitionTasks = [englishTask, frenchTask]

        // Start the analyzer with the input sequence
        try await analyzer?.start(inputSequence: inputSequence)
        ui.status("🎯 Multilingual SpeechAnalyzer started successfully!")
        ui.status("💡 Automatic language detection between English and French enabled")
    }


    func streamAudioToTranscriber(_ buffer: AVAudioPCMBuffer) async throws {
        guard let inputBuilder, let analyzerFormat else {
            throw NSError(domain: "TranscriptionError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid audio setup"])
        }

        // Convert buffer to the correct format
        let converted = try self.converter.convertBuffer(buffer, to: analyzerFormat)
        let input = AnalyzerInput(buffer: converted)

        // Send to analyzer (which will route to both language transcribers)
        inputBuilder.yield(input)
    }

    func finishTranscribing() async throws {
        inputBuilder?.finish()
        try await analyzer?.finalizeAndFinishThroughEndOfInput()

        // Cancel all recognition tasks
        for task in recognitionTasks {
            task.cancel()
        }
        recognitionTasks.removeAll()

        ui.status("🛑 Multilingual transcription finished")
    }

}

// Enhanced buffer converter with error handling
@available(macOS 26.0, *)
final class BufferConverter: Sendable {
    func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        // If formats are the same, return original buffer
        if buffer.format.isEqual(format) {
            return buffer
        }

        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            throw NSError(domain: "ConversionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
        }

        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw NSError(domain: "ConversionError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create converted buffer"])
        }

        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .error, let error = error {
            throw error
        }

        return convertedBuffer
    }
}