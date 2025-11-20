import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation

@available(macOS 26.0, *)
public final class SingleLanguageSpeechRecognizer: @unchecked Sendable {
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

    public init(ui: UserInterface, speechProcessor: SpeechProcessor, locale: String) {
        self.ui = ui
        self.speechProcessor = speechProcessor
        self.localeIdentifier = locale
        self.locale = Locale(identifier: locale)
    }

    public func setUpTranscriber() async throws {
        ui.status("🔧 Setting up \(localeIdentifier) transcriber...")

        // Add startup delay to avoid Speech framework resource conflicts on rapid restart
        try await Task.sleep(for: .milliseconds(200))

        // Create transcriber for the specified language with retry mechanism
        var retryCount = 0
        let maxRetries = 3

        while retryCount < maxRetries {
            do {
                transcriber = SpeechTranscriber(
                    locale: locale,
                    transcriptionOptions: [],
                    reportingOptions: [.volatileResults],
                    attributeOptions: [.audioTimeRange]
                )
                break // Success, exit retry loop
            } catch {
                retryCount += 1
                if retryCount >= maxRetries {
                    throw error // Re-throw final error
                }
                ui.status("⚠️ Transcriber setup failed, retrying... (\(retryCount)/\(maxRetries))")
                try await Task.sleep(for: .milliseconds(500 * retryCount)) // Exponential backoff
            }
        }

        guard let transcriber else {
            throw NSError(domain: "TranscriptionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to setup \(localeIdentifier) transcriber"])
        }

        ui.status("✅ \(localeIdentifier) transcriber created")

        // Add delay before SpeechAnalyzer creation to prevent resource conflicts
        try await Task.sleep(for: .milliseconds(200))

        // Create SpeechAnalyzer with single transcriber - retry if needed
        retryCount = 0
        while retryCount < maxRetries {
            do {
                analyzer = SpeechAnalyzer(modules: [transcriber])
                break // Success, exit retry loop
            } catch {
                retryCount += 1
                if retryCount >= maxRetries {
                    throw error // Re-throw final error
                }
                ui.status("⚠️ SpeechAnalyzer creation failed, retrying... (\(retryCount)/\(maxRetries))")
                try await Task.sleep(for: .milliseconds(500 * retryCount)) // Exponential backoff
            }
        }

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
                globalLogger?.log("👂 [\(locale)] Recognition task started, waiting for results...")
                ui.status("👂 [\(locale)] Recognition task started, waiting for results...")
                for try await case let result in transcriber.results {
                    let text = String(result.text.characters)
                    let startTime = CMTimeGetSeconds(result.range.start)
                    let duration = CMTimeGetSeconds(result.range.duration)
                    globalLogger?.log("📝 [\(locale)] Got result: '\(text)' (final: \(result.isFinal))")
                    ui.status("📝 [\(locale)] Got result: '\(text)' (final: \(result.isFinal))")
                    await processor.process(
                        text: text,
                        isFinal: result.isFinal,
                        startTime: startTime,
                        duration: duration,
                        alternativeCount: result.alternatives.count,
                        locale: locale
                    )
                }
                globalLogger?.log("⚠️ [\(locale)] Recognition task ended - no more results")
                ui.status("⚠️ [\(locale)] Recognition task ended - no more results")
            } catch {
                globalLogger?.log("❌ \(locale) recognition failed: \(error)")
                ui.status("❌ \(locale) recognition failed: \(error)")
            }
        }

        // Start the analyzer with the input sequence
        try await analyzer?.start(inputSequence: inputSequence)
        ui.status("🎯 \(localeIdentifier) SpeechAnalyzer started successfully!")
    }

    public func streamAudioToTranscriber(_ buffer: AVAudioPCMBuffer) async throws {
        guard let inputBuilder, let analyzerFormat else {
            throw NSError(domain: "TranscriptionError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid audio setup for \(localeIdentifier)"])
        }

        // Convert buffer to the correct format
        let converted = try self.converter.convertBuffer(buffer, to: analyzerFormat)
        let input = AnalyzerInput(buffer: converted)

        // Send to analyzer (don't update UI from audio callback)
        inputBuilder.yield(input)
    }

    public func finishTranscribing() async throws {
        ui.status("🛑 Finishing \(localeIdentifier) transcription...")

        // Stop input stream first
        inputBuilder?.finish()

        // Cancel recognition task to stop processing
        recognitionTask?.cancel()

        // Give analyzer time to finish processing any pending input
        try await analyzer?.finalizeAndFinishThroughEndOfInput()

        // Wait for recognition task to complete cancellation
        recognitionTask = nil

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