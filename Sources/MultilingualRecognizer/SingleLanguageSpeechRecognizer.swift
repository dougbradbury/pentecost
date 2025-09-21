import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation

@available(macOS 26.0, *)
final class SingleLanguageSpeechRecognizer: @unchecked Sendable {
    private var inputSequence: AsyncStream<AnalyzerInput>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?

    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?

    private var recognitionTask: Task<(), Never>?
    private var converter = BufferConverter()
    private let ui: UserInterface
    private let speechProcessor: SpeechProcessor
    private let locale: Locale
    private let localeIdentifier: String

    var analyzerFormat: AVAudioFormat?

    init(ui: UserInterface, speechProcessor: SpeechProcessor, locale: String) {
        self.ui = ui
        self.speechProcessor = speechProcessor
        self.localeIdentifier = locale
        self.locale = Locale(identifier: locale)
    }

    func setUpTranscriber() async throws {
        ui.status("🔧 Setting up \(localeIdentifier) transcriber...")

        // Create transcriber for the specified language
        transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )

        guard let transcriber else {
            throw NSError(domain: "TranscriptionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to setup \(localeIdentifier) transcriber"])
        }

        ui.status("✅ \(localeIdentifier) transcriber created")

        // Create SpeechAnalyzer with single transcriber
        analyzer = SpeechAnalyzer(modules: [transcriber])
        ui.status("✅ SpeechAnalyzer created for \(localeIdentifier)")

        // Get the best audio format for this transcriber
        self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        ui.status("🎤 Optimal audio format for \(localeIdentifier): \(analyzerFormat?.description ?? "Unknown")")

        // Create input stream
        (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

        guard let inputSequence else { return }

        // Start recognition task for this language
        let ui = self.ui
        let processor = self.speechProcessor
        let locale = self.localeIdentifier
        recognitionTask = Task { @Sendable in
            do {
                for try await case let result in transcriber.results {
                    let text = String(result.text.characters)
                    let startTime = CMTimeGetSeconds(result.range.start)
                    let duration = CMTimeGetSeconds(result.range.duration)
                    await processor.process(
                        text: text,
                        isFinal: result.isFinal,
                        startTime: startTime,
                        duration: duration,
                        alternativeCount: result.alternatives.count,
                        locale: locale
                    )
                }
            } catch {
                ui.status("❌ \(locale) recognition failed: \(error)")
            }
        }

        // Start the analyzer with the input sequence
        try await analyzer?.start(inputSequence: inputSequence)
        ui.status("🎯 \(localeIdentifier) SpeechAnalyzer started successfully!")
    }

    func streamAudioToTranscriber(_ buffer: AVAudioPCMBuffer) async throws {
        guard let inputBuilder, let analyzerFormat else {
            throw NSError(domain: "TranscriptionError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid audio setup for \(localeIdentifier)"])
        }

        // Convert buffer to the correct format
        let converted = try self.converter.convertBuffer(buffer, to: analyzerFormat)
        let input = AnalyzerInput(buffer: converted)

        // Send to analyzer
        inputBuilder.yield(input)
    }

    func finishTranscribing() async throws {
        inputBuilder?.finish()
        try await analyzer?.finalizeAndFinishThroughEndOfInput()

        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil

        ui.status("🛑 \(localeIdentifier) transcription finished")
    }
}