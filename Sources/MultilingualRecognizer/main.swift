import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation

// MARK: - App Entry Point

@available(macOS 26.0, *)
func main() async {
    let ui: UserInterface = TerminalUI()
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
        return
    }

    let micPermission = await withCheckedContinuation { continuation in
        AVAudioApplication.requestRecordPermission { granted in
            continuation.resume(returning: granted)
        }
    }

    guard micPermission else {
        ui.status("❌ Microphone permission denied")
        return
    }

    ui.status("✅ Permissions granted")

    do {
        // Create processing chain: Recognition → Translation → Display
        let displayProcessor = DisplayProcessor()
        let translationProcessor = TranslationProcessor(nextProcessor: displayProcessor)

        // Create multilingual recognizer with the processing chain
        let recognizer = ProductionMultilingualRecognizer(ui: ui, speechProcessor: translationProcessor)

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
        ui.status("🎙️ Multilingual recognition active... (Ctrl+C to stop)")
        ui.status("🗣️  Try speaking in English or French - both streams will show results!")
        ui.status("📊 Both recognizers running in parallel with confidence measurements")

        // Status updates every 30 seconds
        let statusTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                ui.status("\n📊 Status: Both English and French recognizers running")
            }
        }

        // Keep running indefinitely
        try await Task.sleep(for: .seconds(86400)) // 24 hours

        // Clean up (this won't be reached unless interrupted)
        statusTimer.invalidate()
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        try await recognizer.finishTranscribing()

    } catch {
        ui.status("❌ Error: \(error)")
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
