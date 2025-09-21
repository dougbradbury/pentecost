import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation
import CoreAudio

// MARK: - App Entry Point

@available(macOS 26.0, *)
func setupInputRecognition(ui: UserInterface, speechProcessor: SpeechProcessor, audioService: AudioEngineService) async -> (ProductionMultilingualRecognizer, AVAudioEngine)? {
    ui.status("🎤 Setting up LOCAL audio capture (microphone)")

    do {
        // Create multilingual recognizer for local audio
        let recognizer = ProductionMultilingualRecognizer(ui: ui, speechProcessor: speechProcessor)

        // Set up SpeechAnalyzer with multiple languages
        try await recognizer.setUpMultilingualTranscriber()

        // Set up audio engine with first input device (local microphone)
        let audioEngine = try audioService.createFirstAudioEngine()

        if let device = audioService.getFirstInputDevice() {
            ui.status("✅ LOCAL device: \(device.name)")
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        ui.status("🎤 LOCAL audio: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount) channels")

        // Install audio tap for local audio
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [recognizer] buffer, _ in
            Task { @Sendable in
                do {
                    try await recognizer.streamAudioToTranscriber(buffer)
                } catch {
                    Task { @MainActor in
                        ui.status("❌ Error streaming LOCAL audio: \(error)")
                    }
                }
            }
        }

        // Start audio engine
        try audioEngine.start()
        ui.status("🎙️ LOCAL audio capture active!")

        return (recognizer, audioEngine)

    } catch {
        ui.status("❌ LOCAL audio setup error: \(error)")
        return nil
    }
}

@available(macOS 26.0, *)
func setupRemoteRecognition(ui: UserInterface, speechProcessor: SpeechProcessor, audioService: AudioEngineService) async -> (ProductionMultilingualRecognizer, AVAudioEngine)? {
    ui.status("🔊 Setting up REMOTE audio capture (system/BlackHole)")

    do {
        // Create multilingual recognizer for remote audio
        let recognizer = ProductionMultilingualRecognizer(ui: ui, speechProcessor: speechProcessor)

        // Set up SpeechAnalyzer with multiple languages
        try await recognizer.setUpMultilingualTranscriber()

        // Set up audio engine with second input device (remote/system audio)
        let audioEngine = try audioService.createSecondAudioEngine()

        if let device = audioService.getSecondInputDevice() {
            ui.status("✅ REMOTE device: \(device.name)")
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        ui.status("🔊 REMOTE audio: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount) channels")

        // Install audio tap for remote audio
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [recognizer] buffer, _ in
            Task { @Sendable in
                do {
                    try await recognizer.streamAudioToTranscriber(buffer)
                } catch {
                    Task { @MainActor in
                        ui.status("❌ Error streaming REMOTE audio: \(error)")
                    }
                }
            }
        }

        // Start audio engine for remote capture
        try audioEngine.start()
        ui.status("🔊 REMOTE audio capture active!")

        return (recognizer, audioEngine)

    } catch {
        ui.status("❌ REMOTE audio setup error: \(error)")
        return nil
    }
}

@available(macOS 26.0, *)
func main() async {
    let ui: UserInterface = TerminalUI()

    ui.status("🌍 Dual Input Multilingual Recognizer - English & French")
    ui.status("📱 Platform: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")

    // Request permissions upfront
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

    // Create separate processing chains for each audio stream

    // LOCAL (microphone) processing chain
    let terminalProcessor = TwoColumnTerminalProcessor(terminalWidth: 120)
    let localTranslationProcessor = TranslationProcessor(nextProcessor: terminalProcessor)
    let localLanguageFilter = LanguageFilterProcessor(nextProcessor: localTranslationProcessor)

    // REMOTE (BlackHole) processing chain
    let remoteTranslationProcessor = TranslationProcessor(nextProcessor: terminalProcessor)
    let remoteLanguageFilter = LanguageFilterProcessor(nextProcessor: remoteTranslationProcessor)

    // Create audio service and setup UI
    let audioService = AudioEngineService()
    let audioSetupUI = AudioSetupUI(audioService: audioService)

    // Run device selection
    do {
        try await audioSetupUI.runDeviceSelection()
    } catch {
        ui.status("❌ Audio setup failed: \(error)")
        return
    }

    // Set up input recognition (local microphone)
    guard let (inputRecognizer, inputAudioEngine) = await setupInputRecognition(ui: ui, speechProcessor: localLanguageFilter, audioService: audioService) else {
        return
    }

    // Set up remote recognition (system/BlackHole audio)
    guard let (remoteRecognizer, remoteAudioEngine) = await setupRemoteRecognition(ui: ui, speechProcessor: remoteLanguageFilter, audioService: audioService) else {
        return
    }

    // Status updates every 30 seconds
    let statusTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
        Task { @MainActor in
            ui.status("\n📊 Status: Dual audio capture active - Input & Output recognizers running")
        }
    }

    do {
        // Keep running indefinitely
        try await Task.sleep(for: .seconds(86400)) // 24 hours

        // Clean up (this won't be reached unless interrupted)
        statusTimer.invalidate()
        inputAudioEngine.stop()
        inputAudioEngine.inputNode.removeTap(onBus: 0)
        remoteAudioEngine.stop()
        remoteAudioEngine.inputNode.removeTap(onBus: 0)
        try await inputRecognizer.finishTranscribing()
        try await remoteRecognizer.finishTranscribing()
    } catch {
        // Handle cleanup on interruption
        statusTimer.invalidate()
        inputAudioEngine.stop()
        inputAudioEngine.inputNode.removeTap(onBus: 0)
        remoteAudioEngine.stop()
        remoteAudioEngine.inputNode.removeTap(onBus: 0)
        try? await inputRecognizer.finishTranscribing()
        try? await remoteRecognizer.finishTranscribing()
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
