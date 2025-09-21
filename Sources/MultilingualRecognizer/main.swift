import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation

// MARK: - App Entry Point

@available(macOS 26.0, *)
func setupRecognition(ui: UserInterface, speechProcessor: SpeechProcessor) async -> (ProductionMultilingualRecognizer, AVAudioEngine)? {
    ui.status("🌍 Multilingual Recognizer - English & French with Automatic Language Detection")
    ui.status("📱 Platform: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")

    // Request permissions
    let speechAuth = await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
            continuation.resume(returning: status)
        }
    }

    guard speechAuth == .authorized else {
        ui.status("❌ Speech recognition not authorized")
        return nil
    }

    let micPermission = await withCheckedContinuation { continuation in
        AVAudioApplication.requestRecordPermission { granted in
            continuation.resume(returning: granted)
        }
    }

    guard micPermission else {
        ui.status("❌ Microphone permission denied")
        return nil
    }

    ui.status("✅ Permissions granted")

    do {
        // Create multilingual recognizer with the processing chain
        let recognizer = ProductionMultilingualRecognizer(ui: ui, speechProcessor: speechProcessor)

        // Set up SpeechAnalyzer with multiple languages
        try await recognizer.setUpMultilingualTranscriber()

        // Set up audio engine
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        ui.status("🎤 Audio input: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount) channels")

        // Install audio tap
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [recognizer] buffer, _ in
            Task { @Sendable in
                do {
                    try await recognizer.streamAudioToTranscriber(buffer)
                } catch {
                    Task { @MainActor in
                        ui.status("❌ Error streaming audio: \(error)")
                    }
                }
            }
        }

        // Start audio engine
        try audioEngine.start()
        ui.status("🎙️ Multilingual recognition active with real-time translation!")
        ui.status("🗣️  Speak in English or French - translations will appear!")

        return (recognizer, audioEngine)

    } catch {
        ui.status("❌ Error: \(error)")
        return nil
    }
}

@available(macOS 26.0, *)
func main() async {
    let ui: UserInterface = TerminalUI()

    // Create processing chain: Recognition → Language Filter → Translation → Two-Column Display
    let terminalProcessor = TwoColumnTerminalProcessor(terminalWidth: 120)
    let translationProcessor = TranslationProcessor(nextProcessor: terminalProcessor)
    let languageFilter = LanguageFilterProcessor(nextProcessor: translationProcessor)

    // Set up recognition
    guard let (recognizer, audioEngine) = await setupRecognition(ui: ui, speechProcessor: languageFilter) else {
        return
    }

    // Status updates every 30 seconds
    let statusTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
        Task { @MainActor in
            ui.status("\n📊 Status: Both English and French recognizers running")
        }
    }

    do {
        // Keep running indefinitely
        try await Task.sleep(for: .seconds(86400)) // 24 hours

        // Clean up (this won't be reached unless interrupted)
        statusTimer.invalidate()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        try await recognizer.finishTranscribing()
    } catch {
        // Handle cleanup on interruption
        statusTimer.invalidate()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        try? await recognizer.finishTranscribing()
    }
}

// App entry point
if #available(macOS 26.0, *) {
    Task {
        await main()
    }
    RunLoop.main.run()
} else {
    print("❌ Requires macOS 26.0+")
    exit(1)
}
