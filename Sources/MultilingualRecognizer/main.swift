import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation
import CoreAudio

// MARK: - Error Types

enum AudioError: Error {
    case formatError(String)
    case deviceError(String)
}

// MARK: - App Entry Point

@available(macOS 26.0, *)
func setupInputRecognition(ui: UserInterface, speechProcessor: SpeechProcessor, audioService: AudioEngineService) async -> (englishRecognizer: SingleLanguageSpeechRecognizer, frenchRecognizer: SingleLanguageSpeechRecognizer, audioEngine: AVAudioEngine)? {
    ui.status("🎤 Setting up LOCAL audio capture (microphone)")

    do {
        // Create recognizers sequentially to avoid Speech framework conflicts
        ui.status("🔧 Creating English recognizer...")
        let englishRecognizer = SingleLanguageSpeechRecognizer(ui: ui, speechProcessor: speechProcessor, locale: "en-US")

        ui.status("🔧 Setting up English transcriber...")
        try await englishRecognizer.setUpTranscriber()

        // Longer delay between language setups to ensure Speech framework stability
        ui.status("⏳ Waiting before French setup...")
        try await Task.sleep(for: .milliseconds(1000))

        ui.status("🔧 Creating French recognizer...")
        let frenchRecognizer = SingleLanguageSpeechRecognizer(ui: ui, speechProcessor: speechProcessor, locale: "fr-FR")

        ui.status("🔧 Setting up French transcriber...")
        try await frenchRecognizer.setUpTranscriber()

        // Set up audio engine with first input device (local microphone)
        let audioEngine = try audioService.createFirstAudioEngine()

        if let device = audioService.getFirstInputDevice() {
            ui.status("✅ LOCAL device: \(device.name)")
        }

        let inputNode = audioEngine.inputNode
        let deviceFormat = inputNode.outputFormat(forBus: 0)
        ui.status("🎤 LOCAL device format: \(deviceFormat.sampleRate)Hz, \(deviceFormat.channelCount) channels")

        // Use 48kHz format for speech recognition - proven to work best
        guard let tapFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 1, interleaved: false) else {
            throw AudioError.formatError("Failed to create tap audio format")
        }
        ui.status("🎤 LOCAL tap format: \(tapFormat.sampleRate)Hz, \(tapFormat.channelCount) channels")

        // Install audio tap for local audio - stream to both recognizers
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [englishRecognizer, frenchRecognizer] buffer, _ in
            Task { @Sendable in
                do {
                    try await englishRecognizer.streamAudioToTranscriber(buffer)
                    try await frenchRecognizer.streamAudioToTranscriber(buffer)
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

        return (englishRecognizer, frenchRecognizer, audioEngine)

    } catch {
        ui.status("❌ LOCAL audio setup error: \(error)")
        return nil
    }
}

@available(macOS 26.0, *)
func setupRemoteRecognition(ui: UserInterface, speechProcessor: SpeechProcessor, audioService: AudioEngineService) async -> (englishRecognizer: SingleLanguageSpeechRecognizer, frenchRecognizer: SingleLanguageSpeechRecognizer, audioEngine: AVAudioEngine)? {
    ui.status("🔊 Setting up REMOTE audio capture (system/BlackHole)")

    do {
        // Create recognizers sequentially to avoid Speech framework conflicts
        ui.status("🔧 Creating English recognizer for REMOTE...")
        let englishRecognizer = SingleLanguageSpeechRecognizer(ui: ui, speechProcessor: speechProcessor, locale: "en-US")

        ui.status("🔧 Setting up English transcriber for REMOTE...")
        try await englishRecognizer.setUpTranscriber()

        // Longer delay between language setups to ensure Speech framework stability
        ui.status("⏳ Waiting before French setup for REMOTE...")
        try await Task.sleep(for: .milliseconds(1000))

        ui.status("🔧 Creating French recognizer for REMOTE...")
        let frenchRecognizer = SingleLanguageSpeechRecognizer(ui: ui, speechProcessor: speechProcessor, locale: "fr-FR")

        ui.status("🔧 Setting up French transcriber for REMOTE...")
        try await frenchRecognizer.setUpTranscriber()

        // Set up audio engine with second input device (remote/system audio)
        let audioEngine = try audioService.createSecondAudioEngine()

        if let device = audioService.getSecondInputDevice() {
            ui.status("✅ REMOTE device: \(device.name)")
        }

        let inputNode = audioEngine.inputNode
        let deviceFormat = inputNode.outputFormat(forBus: 0)
        ui.status("🔊 REMOTE device format: \(deviceFormat.sampleRate)Hz, \(deviceFormat.channelCount) channels")

        // Use 48kHz format for speech recognition - proven to work best
        guard let tapFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 1, interleaved: false) else {
            throw AudioError.formatError("Failed to create tap audio format")
        }
        ui.status("🔊 REMOTE tap format: \(tapFormat.sampleRate)Hz, \(tapFormat.channelCount) channels")

        // Install audio tap for remote audio - stream to both recognizers
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [englishRecognizer, frenchRecognizer] buffer, _ in
            Task { @Sendable in
                do {
                    try await englishRecognizer.streamAudioToTranscriber(buffer)
                    try await frenchRecognizer.streamAudioToTranscriber(buffer)
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

        return (englishRecognizer, frenchRecognizer, audioEngine)

    } catch {
        ui.status("❌ REMOTE audio setup error: \(error)")
        return nil
    }
}

// MARK: - Signal Handling

import Darwin

// Global shutdown flag (nonisolated for signal handler access)
nonisolated(unsafe) var shutdownRequested: Bool = false

func setupSignalHandling() {
    // Simple signal handlers that just set a flag
    signal(SIGINT) { _ in
        print("\n🛑 Received shutdown signal (Ctrl-C)...")
        shutdownRequested = true
    }

    signal(SIGTERM) { _ in
        print("\n🛑 Received termination signal...")
        shutdownRequested = true
    }
}

@available(macOS 26.0, *)
func performCleanShutdown(
    ui: UserInterface,
    statusTimer: Timer,
    inputAudioEngine: AVAudioEngine,
    remoteAudioEngine: AVAudioEngine,
    inputEnglishRecognizer: SingleLanguageSpeechRecognizer,
    inputFrenchRecognizer: SingleLanguageSpeechRecognizer,
    remoteEnglishRecognizer: SingleLanguageSpeechRecognizer,
    remoteFrenchRecognizer: SingleLanguageSpeechRecognizer
) async {
    ui.status("🛑 Shutting down gracefully...")
    statusTimer.invalidate()

    // Stop audio engines first to prevent new audio processing
    inputAudioEngine.stop()
    remoteAudioEngine.stop()

    // Remove audio taps to stop audio callbacks
    inputAudioEngine.inputNode.removeTap(onBus: 0)
    remoteAudioEngine.inputNode.removeTap(onBus: 0)

    // Allow brief time for any pending audio processing to complete
    do {
        try await Task.sleep(for: .milliseconds(100))
    } catch {
        // Sleep interrupted, continue cleanup
    }

    // Finish transcription in order to properly close Speech framework resources
    do {
        try await inputEnglishRecognizer.finishTranscribing()
        try await inputFrenchRecognizer.finishTranscribing()
        try await remoteEnglishRecognizer.finishTranscribing()
        try await remoteFrenchRecognizer.finishTranscribing()
    } catch {
        ui.status("⚠️ Error during transcription cleanup: \(error)")
    }

    ui.status("✅ Shutdown complete")

    // Exit the process cleanly
    exit(0)
}

@available(macOS 26.0, *)
func main() async {
    let ui: UserInterface = TerminalUI()

    // Display beautiful Pentecost ASCII art and branding
    print("""

    ╔═════════════════════════======══════════════════════════════════════════════════════╗
    ║                                                                                     ║
    ║    ██████╗ ███████╗███╗   ██╗████████╗███████╗ ██████╗ ██████╗ ███████╗████████╗    ║
    ║    ██╔══██╗██╔════╝████╗  ██║╚══██╔══╝██╔════╝██╔════╝██╔═══██╗██╔════╝╚══██╔══╝    ║
    ║    ██████╔╝█████╗  ██╔██╗ ██║   ██║   █████╗  ██║     ██║   ██║███████╗   ██║       ║
    ║    ██╔═══╝ ██╔══╝  ██║╚██╗██║   ██║   ██╔══╝  ██║     ██║   ██║╚════██║   ██║       ║
    ║    ██║     ███████╗██║ ╚████║   ██║   ███████╗╚██████╗╚██████╔╝███████║   ██║       ║
    ║    ╚═╝     ╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝ ╚═════╝ ╚═════╝ ╚══════╝   ╚═╝       ║
    ║                                                                                     ║
    ║                🔥 Where Everyone Understands Everyone Else 🕊️                       ║
    ║                                                                                     ║
    ║             Real-time Multilingual Speech Recognition & Translation                 ║
    ║                          English ⟷ French                                           ║
    ║                                                                                     ║
    ║      "And they were all filled with the Holy Spirit and began to speak in other     ║
    ║       tongues... each one heard their own language being spoken." - Acts 2:4,6      ║
    ║                                                                                     ║
    ╚════════════════════════════════════════════════════════════════════════════======═══╝

    """)

    ui.status("📱 Platform: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
    ui.status("🕊️ Pentecost v1.0 - The Miracle of Understanding")
    print("")

    // Set up signal handling for graceful shutdown
    setupSignalHandling()

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

    // Add startup delay to ensure clean Speech framework state
    ui.status("⏳ Initializing Speech framework...")
    do {
        try await Task.sleep(for: .milliseconds(250))
    } catch {
        // Sleep cancellation is not a critical error
        ui.status("⚠️ Initialization delay interrupted")
    }

    // Create separate processing chains for each audio stream

    // Shared processors
    let terminalProcessor = TwoColumnTerminalProcessor()
    let transcriptProcessor = TranscriptFileProcessor()
    let broadcastProcessor = BroadcastProcessor(processors: [terminalProcessor, transcriptProcessor])

    // LOCAL (microphone) processing chain
    let localTranslationProcessor = TranslationProcessor(nextProcessor: broadcastProcessor)
    let localLanguageFilter = LanguageFilterProcessor(nextProcessor: localTranslationProcessor)

    // REMOTE (BlackHole) processing chain
    let remoteTranslationProcessor = TranslationProcessor(nextProcessor: broadcastProcessor)
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
    guard let (inputEnglishRecognizer, inputFrenchRecognizer, inputAudioEngine) = await setupInputRecognition(ui: ui, speechProcessor: localLanguageFilter, audioService: audioService) else {
        return
    }

    // Add delay between local and remote setup to avoid overwhelming Speech framework
    ui.status("⏳ Pausing before remote audio setup...")
    do {
        try await Task.sleep(for: .milliseconds(1500))
    } catch {
        ui.status("⚠️ Remote setup delay interrupted")
    }

    // Set up remote recognition (system/BlackHole audio)
    guard let (remoteEnglishRecognizer, remoteFrenchRecognizer, remoteAudioEngine) = await setupRemoteRecognition(ui: ui, speechProcessor: remoteLanguageFilter, audioService: audioService) else {
        return
    }

    // Status updates every 30 seconds
    let statusTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
        Task { @MainActor in
            ui.status("\n📊 Status: Dual audio capture active - Input & Output recognizers running")
        }
    }

    // Keep running until signal is received
    while !shutdownRequested {
        do {
            try await Task.sleep(for: .seconds(1))
        } catch {
            // Sleep interrupted, continue checking shutdown flag
        }
    }

    // Perform clean shutdown
    await performCleanShutdown(
        ui: ui,
        statusTimer: statusTimer,
        inputAudioEngine: inputAudioEngine,
        remoteAudioEngine: remoteAudioEngine,
        inputEnglishRecognizer: inputEnglishRecognizer,
        inputFrenchRecognizer: inputFrenchRecognizer,
        remoteEnglishRecognizer: remoteEnglishRecognizer,
        remoteFrenchRecognizer: remoteFrenchRecognizer
    )
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
