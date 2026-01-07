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
    private var analysisTask: Task<(), Never>?  // Task for analyzeSequence()
    private var converter = BufferConverter()
    private let ui: UserInterface
    private let speechProcessor: SpeechProcessor
    private let locale: Locale
    private let localeIdentifier: String
    private let source: String

    var analyzerFormat: AVAudioFormat?

    init(ui: UserInterface, speechProcessor: SpeechProcessor, locale: String, source: String) {
        self.ui = ui
        self.speechProcessor = speechProcessor
        self.localeIdentifier = locale
        self.locale = Locale(identifier: locale)
        self.source = source
    }

    func setUpTranscriber() async throws {
        ui.status("🔧 Setting up \(localeIdentifier) transcriber...")

        // Step 1: Create transcriber for the specified language
        // Note: Preset API may not be available in macOS 26.0, using manual configuration
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

        // Step 2: Brief delay to let Speech framework fully initialize the transcriber
        // Without this, bestAvailableAudioFormat() can crash during type instantiation
        try await Task.sleep(for: .milliseconds(100))

        // Step 3: Create input stream
        (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

        guard let inputSequence else {
            throw NSError(domain: "TranscriptionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create input sequence"])
        }

        // Step 4: Get audio format from Speech framework
        // Query the best available format that's compatible with this transcriber
        let audioFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        guard let audioFormat else {
            throw NSError(domain: "TranscriptionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No compatible audio format available"])
        }
        self.analyzerFormat = audioFormat
        ui.status("🎤 Using audio format for \(localeIdentifier): \(audioFormat.description)")

        analyzer = SpeechAnalyzer(modules: [transcriber])
        ui.status("✅ SpeechAnalyzer created for \(localeIdentifier)")

        // Step 7: Start reading results BEFORE starting analysis
        // This is critical per Apple's example
        let ui = self.ui
        let processor = self.speechProcessor
        let locale = self.localeIdentifier
        let source = self.source
        let localTranscriber = transcriber
        recognitionTask = Task { @Sendable in
            do {
                for try await case let result in localTranscriber.results {
                    let text = String(result.text.characters)
                    let startTime = CMTimeGetSeconds(result.range.start)
                    let duration = CMTimeGetSeconds(result.range.duration)
                    await processor.process(
                        text: text,
                        isFinal: result.isFinal,
                        startTime: startTime,
                        duration: duration,
                        alternativeCount: result.alternatives.count,
                        locale: locale,
                        source: source
                    )
                }
            } catch {
                ui.status("❌ \(locale) recognition failed: \(error)")
            }
        }

        // Step 6: Start analysis using analyzeSequence (non-blocking, structured concurrency)
        // We use a separate task so it doesn't block setup
        let localAnalyzer = analyzer
        analysisTask = Task { @Sendable in
            do {
                let lastSampleTime = try await localAnalyzer?.analyzeSequence(inputSequence)
                ui.status("🎯 \(locale) analysis completed, last sample: \(lastSampleTime?.seconds ?? 0)")
            } catch {
                ui.status("❌ \(locale) analysis failed: \(error)")
            }
        }

        // Give the analyzer a moment to actually start before returning
        try await Task.sleep(for: .milliseconds(50))
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
        ui.status("🛑 Finishing \(localeIdentifier) transcription...")

        // Step 1: Stop input stream to signal no more audio coming
        inputBuilder?.finish()

        // Step 2: Let analyzer finalize gracefully - this will complete the analyzeSequence() call
        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
        } catch {
            // Ignore errors during finalization - analyzer may already be cancelled
            ui.status("⚠️ \(localeIdentifier) finalization error (expected during shutdown): \(error)")
        }

        // Step 3: Now cancel tasks - analysis task should be done, but recognition task may still be reading
        recognitionTask?.cancel()
        analysisTask?.cancel()

        // Step 4: Wait for tasks to complete
        recognitionTask = nil
        analysisTask = nil

        // Add brief delay to ensure Speech framework resources are released
        try await Task.sleep(for: .milliseconds(100))

        // Clean up resources to prevent conflicts on restart
        analyzer = nil
        transcriber = nil
        inputBuilder = nil
        inputSequence = nil
        analyzerFormat = nil

        ui.status("✅ \(localeIdentifier) transcription finished and resources cleaned up")
    }
}