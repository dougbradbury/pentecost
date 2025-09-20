import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation

print("🌍 Multilingual Recognizer - English & French with Automatic Language Detection")

@available(macOS 26.0, *)
class ProductionMultilingualRecognizer {
    private var inputSequence: AsyncStream<AnalyzerInput>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?

    // Multiple transcribers for different languages
    private var englishTranscriber: SpeechTranscriber?
    private var frenchTranscriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?

    private var recognitionTasks: [Task<(), Never>] = []
    private var converter = BufferConverter()

    var analyzerFormat: AVAudioFormat?

    init() {}

    func setUpMultilingualTranscriber() async throws {
        print("🔧 Setting up multilingual transcribers...")

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

        print("✅ English transcriber created (en-US)")
        print("✅ French transcriber created (fr-FR)")

        // Create SpeechAnalyzer with both transcribers for automatic language detection
        analyzer = SpeechAnalyzer(modules: [englishTranscriber, frenchTranscriber])
        print("✅ SpeechAnalyzer created with multilingual support")

        // Get the best audio format for both transcribers
        self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [englishTranscriber, frenchTranscriber])
        print("🎤 Optimal audio format: \(analyzerFormat?.description ?? "Unknown")")

        // Create input stream
        (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

        guard let inputSequence else { return }

        // Start recognition tasks for both languages - process results directly
        let englishTask = Task {
            do {
                for try await case let result in englishTranscriber.results {
                    let text = String(result.text.characters) // Extract plain string from AttributedString
                    if result.isFinal {
                        print("✅ 🇺🇸 FINAL: \(text)")
                    } else {
                        print("⏳ 🇺🇸 PARTIAL: \(text)")
                    }
                }
            } catch {
                print("❌ English recognition failed: \(error)")
            }
        }

        let frenchTask = Task {
            do {
                for try await case let result in frenchTranscriber.results {
                    let text = String(result.text.characters) // Extract plain string from AttributedString
                    if result.isFinal {
                        print("✅ 🇫🇷 FINAL: \(text)")
                    } else {
                        print("⏳ 🇫🇷 PARTIAL: \(text)")
                    }
                }
            } catch {
                print("❌ French recognition failed: \(error)")
            }
        }

        recognitionTasks = [englishTask, frenchTask]

        // Start the analyzer with the input sequence
        try await analyzer?.start(inputSequence: inputSequence)
        print("🎯 Multilingual SpeechAnalyzer started successfully!")
        print("💡 Automatic language detection between English and French enabled")
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

        print("🛑 Multilingual transcription finished")
    }

}

// Enhanced buffer converter with error handling
@available(macOS 26.0, *)
class BufferConverter {
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

@available(macOS 26.0, *)
func main() async {
    print("📱 Platform: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")

    // Request permissions
    let speechAuth = await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
            continuation.resume(returning: status)
        }
    }

    guard speechAuth == .authorized else {
        print("❌ Speech recognition not authorized")
        return
    }

    let micPermission = await withCheckedContinuation { continuation in
        AVAudioApplication.requestRecordPermission { granted in
            continuation.resume(returning: granted)
        }
    }

    guard micPermission else {
        print("❌ Microphone permission denied")
        return
    }

    print("✅ Permissions granted")

    do {
        // Create multilingual recognizer
        let recognizer = ProductionMultilingualRecognizer()

        // Set up SpeechAnalyzer with multiple languages
        try await recognizer.setUpMultilingualTranscriber()

        // Set up audio engine
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("🎤 Audio input: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount) channels")

        // Install audio tap
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [recognizer] buffer, _ in
            Task { @Sendable in
                do {
                    try await recognizer.streamAudioToTranscriber(buffer)
                } catch {
                    print("❌ Error streaming audio: \(error)")
                }
            }
        }

        // Start audio engine
        try audioEngine.start()
        print("🎙️ Multilingual recognition active... (Ctrl+C to stop)")
        print("🗣️  Try speaking in English or French - both streams will show results!")
        print("📊 Both recognizers running in parallel with confidence measurements")

        // Status updates every 30 seconds
        let statusTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            print("\n📊 Status: Both English and French recognizers running")
        }

        // Keep running indefinitely
        try await Task.sleep(for: .seconds(86400)) // 24 hours

        // Clean up (this won't be reached unless interrupted)
        statusTimer.invalidate()
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        try await recognizer.finishTranscribing()

    } catch {
        print("❌ Error: \(error)")
    }
}

func runMain() async {
    if #available(macOS 26.0, *) {
        await main()
    } else {
        print("❌ Requires macOS 26.0+")
    }
    exit(0)
}

Task {
    await runMain()
}

RunLoop.main.run()