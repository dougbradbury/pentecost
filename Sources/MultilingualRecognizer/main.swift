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
func setupInputRecognition(ui: UserInterface, speechProcessor: SpeechProcessor, audioService: AudioEngineService, source: String) async -> (englishRecognizer: SingleLanguageSpeechRecognizer, frenchRecognizer: SingleLanguageSpeechRecognizer, audioEngine: AVAudioEngine)? {
    ui.status("🎤 Setting up LOCAL audio capture (microphone)")

    do {
        // Create recognizers sequentially to avoid Speech framework conflicts
        ui.status("🔧 Creating English recognizer...")
        let englishRecognizer = SingleLanguageSpeechRecognizer(ui: ui, speechProcessor: speechProcessor, locale: "en-US", source: source)

        ui.status("🔧 Setting up English transcriber...")
        try await englishRecognizer.setUpTranscriber()

        // REMOVED DELAY FOR APPLE FEEDBACK CRASH REPRODUCTION
        // Original workaround: try await Task.sleep(for: .milliseconds(300))
        // Without this delay: second recognizer crashes during Swift metadata instantiation

        ui.status("🔧 Creating French recognizer...")
        let frenchRecognizer = SingleLanguageSpeechRecognizer(ui: ui, speechProcessor: speechProcessor, locale: "fr-CA", source: source)

        ui.status("🔧 Setting up French transcriber...")
        try await frenchRecognizer.setUpTranscriber()

        // REMOVED DELAY FOR APPLE FEEDBACK CRASH REPRODUCTION
        // Original workaround: try await Task.sleep(for: .milliseconds(300))
        // Without this delay: crashes during audio startup

        // Set up audio engine with first input device (local microphone)
        let audioEngine = try await audioService.createFirstAudioEngine()

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
        // Note: No Task wrapper needed - actor isolation handles serialization
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak englishRecognizer, weak frenchRecognizer] buffer, _ in
            guard let english = englishRecognizer, let french = frenchRecognizer else { return }
            Task {
                do {
                    try await english.streamAudioToTranscriber(buffer)
                    try await french.streamAudioToTranscriber(buffer)
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
func setupRemoteRecognition(ui: UserInterface, speechProcessor: SpeechProcessor, audioService: AudioEngineService, source: String) async -> (englishRecognizer: SingleLanguageSpeechRecognizer, frenchRecognizer: SingleLanguageSpeechRecognizer, audioEngine: AVAudioEngine)? {
    ui.status("🔊 Setting up REMOTE audio capture (system/BlackHole)")

    do {
        // Create recognizers sequentially to avoid Speech framework conflicts
        ui.status("🔧 Creating English recognizer for REMOTE...")
        let englishRecognizer = SingleLanguageSpeechRecognizer(ui: ui, speechProcessor: speechProcessor, locale: "en-US", source: source)

        ui.status("🔧 Setting up English transcriber for REMOTE...")
        try await englishRecognizer.setUpTranscriber()

        // REMOVED DELAY FOR APPLE FEEDBACK CRASH REPRODUCTION
        // Original workaround: try await Task.sleep(for: .milliseconds(300))
        // Without this delay: second recognizer crashes during Swift metadata instantiation

        ui.status("🔧 Creating French recognizer for REMOTE...")
        let frenchRecognizer = SingleLanguageSpeechRecognizer(ui: ui, speechProcessor: speechProcessor, locale: "fr-CA", source: source)

        ui.status("🔧 Setting up French transcriber for REMOTE...")
        try await frenchRecognizer.setUpTranscriber()

        // REMOVED DELAY FOR APPLE FEEDBACK CRASH REPRODUCTION
        // Original workaround: try await Task.sleep(for: .milliseconds(300))
        // Without this delay: crashes during audio startup

        // Set up audio engine with second input device (remote/system audio)
        let audioEngine = try await audioService.createSecondAudioEngine()

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
        // Note: Actor isolation ensures safe concurrent access to recognizers
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak englishRecognizer, weak frenchRecognizer] buffer, _ in
            guard let english = englishRecognizer, let french = frenchRecognizer else { return }
            Task {
                do {
                    try await english.streamAudioToTranscriber(buffer)
                    try await french.streamAudioToTranscriber(buffer)
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

// MARK: - Keyboard Input Handling

/// Set up raw terminal mode to capture individual keystrokes
func enableRawMode() -> termios? {
    var originalTermios = termios()
    guard tcgetattr(STDIN_FILENO, &originalTermios) == 0 else {
        return nil
    }

    var raw = originalTermios
    raw.c_lflag &= ~(UInt(ICANON | ECHO))
    raw.c_cc.16 = 0  // VMIN = 0 (non-blocking)
    raw.c_cc.17 = 0  // VTIME = 0

    guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == 0 else {
        return nil
    }

    return originalTermios
}

/// Restore terminal to original mode
func disableRawMode(_ originalTermios: termios) {
    var term = originalTermios
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &term)
}

/// Monitor keyboard input for Ctrl+N command
@available(macOS 26.0, *)
func startKeyboardMonitoring(
    transcriptProcessor: TranscriptFileProcessor,
    terminalProcessor: TwoColumnTerminalProcessor,
    ui: UserInterface
) -> Task<Void, Never> {
    return Task {
        var buffer = [UInt8](repeating: 0, count: 16)

        while !shutdownRequested {
            do {
                // Non-blocking read with timeout
                try await Task.sleep(for: .milliseconds(100))

                // Read from stdin using Darwin's read (non-blocking)
                let bytesRead = read(STDIN_FILENO, &buffer, buffer.count)

                guard bytesRead > 0 else { continue }

                // Process each byte
                for i in 0..<bytesRead {
                    let byte = buffer[i]
                    // Ctrl+N is ASCII 14 (0x0E)
                    if byte == 14 {
                        await handleNewTranscriptCommand(
                            transcriptProcessor: transcriptProcessor,
                            terminalProcessor: terminalProcessor,
                            ui: ui
                        )
                    }
                }
            } catch {
                // Sleep interrupted, continue
            }
        }
    }
}

/// Handle the Ctrl+N command to start a new transcript file
@available(macOS 26.0, *)
func handleNewTranscriptCommand(
    transcriptProcessor: TranscriptFileProcessor,
    terminalProcessor: TwoColumnTerminalProcessor,
    ui: UserInterface
) async {
    _ = await transcriptProcessor.startNewTranscriptFile()
    await terminalProcessor.clear()
}

@available(macOS 26.0, *)
func performCleanShutdown(
    ui: UserInterface,
    statusTimer: Timer,
    inputAudioEngine: AVAudioEngine,
    remoteAudioEngine: AVAudioEngine?,
    inputEnglishRecognizer: SingleLanguageSpeechRecognizer,
    inputFrenchRecognizer: SingleLanguageSpeechRecognizer,
    remoteEnglishRecognizer: SingleLanguageSpeechRecognizer?,
    remoteFrenchRecognizer: SingleLanguageSpeechRecognizer?,
    keyboardMonitorTask: Task<Void, Never>?,
    originalTermios: termios?
) async {
    // Clear screen for clean shutdown message display
    print("\u{001B}[2J\u{001B}[H", terminator: "")

    ui.status("🛑 Shutting down gracefully...")

    // Cancel keyboard monitoring task
    keyboardMonitorTask?.cancel()

    // Restore terminal mode
    if let originalTermios = originalTermios {
        disableRawMode(originalTermios)
    }

    statusTimer.invalidate()

    // Stop audio engines first to prevent new audio processing
    inputAudioEngine.stop()
    remoteAudioEngine?.stop()

    // Remove audio taps to stop audio callbacks
    inputAudioEngine.inputNode.removeTap(onBus: 0)
    if let remoteAudioEngine = remoteAudioEngine {
        remoteAudioEngine.inputNode.removeTap(onBus: 0)
    }

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
        if let remoteEnglishRecognizer = remoteEnglishRecognizer {
            try await remoteEnglishRecognizer.finishTranscribing()
        }
        if let remoteFrenchRecognizer = remoteFrenchRecognizer {
            try await remoteFrenchRecognizer.finishTranscribing()
        }
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

    // Create separate processing chains for each audio stream

    // Shared processors
    let terminalProcessor = TwoColumnTerminalProcessor()
    let transcriptProcessor = TranscriptFileProcessor()
    let broadcastProcessor = BroadcastProcessor(processors: [terminalProcessor, transcriptProcessor])

    // LOCAL (microphone) processing chain
    // Chain: Artifact Filter → Min Length Filter → Language Filter → Translation → Broadcast
    let localTranslationProcessor = TranslationProcessor(nextProcessor: broadcastProcessor)
    let localMinLengthFilter = MinimumLengthFilterProcessor(nextProcessor: localTranslationProcessor)
    let localLanguageFilter = LanguageFilterProcessor(nextProcessor: localMinLengthFilter)
    let localArtifactFilter = ArtifactFilterProcessor(nextProcessor: localLanguageFilter)

    // REMOTE (BlackHole) processing chain
    // Chain: Artifact Filter → Min Length Filter → Language Filter → Translation → Broadcast
    let remoteTranslationProcessor = TranslationProcessor(nextProcessor: broadcastProcessor)
    let remoteMinLengthFilter = MinimumLengthFilterProcessor(nextProcessor: remoteTranslationProcessor)
    let remoteLanguageFilter = LanguageFilterProcessor(nextProcessor: remoteMinLengthFilter)
    let remoteArtifactFilter = ArtifactFilterProcessor(nextProcessor: remoteLanguageFilter)

    // Create audio service and setup coordinator with dependency injection
    let audioService = AudioEngineService()
    let deviceSelector = TerminalDeviceSelector()
    let audioSetupCoordinator = AudioSetupCoordinator(
        audioService: audioService,
        deviceSelector: deviceSelector,
        ui: ui
    )

    // Run device selection
    do {
        try await audioSetupCoordinator.runDeviceSelection()
    } catch {
        ui.status("❌ Audio setup failed: \(error)")
        return
    }

    // Set up input recognition (local microphone)
    guard let (inputEnglishRecognizer, inputFrenchRecognizer, inputAudioEngine) = await setupInputRecognition(ui: ui, speechProcessor: localArtifactFilter, audioService: audioService, source: "local") else {
        return
    }

    // NOT NEEDED: Previously had 800ms delay between audio engine creation.
    // Tested and removed - Core Audio handles concurrent engine creation fine.
    // Actor isolation protects Speech framework objects during initialization.

    // Set up remote recognition (system/BlackHole audio)
    guard let (remoteEnglishRecognizer, remoteFrenchRecognizer, remoteAudioEngine) = await setupRemoteRecognition(ui: ui, speechProcessor: remoteArtifactFilter, audioService: audioService, source: "remote") else {
        return
    }

    // NOT NEEDED: Previously had 1000ms "final stabilization" delay here.
    // Tested and removed - the crashes this was trying to prevent were actually
    // caused by @unchecked Sendable data races, which are now fixed with proper
    // actor isolation. Speech framework initialization completes during the
    // setUpTranscriber() calls above.
    ui.status("✅ Speech framework initialized with actor protection")

    // Enable raw terminal mode for keyboard input
    let originalTermios = enableRawMode()
    if originalTermios == nil {
        ui.status("⚠️ Could not enable raw terminal mode - keyboard shortcuts disabled")
    } else {
        ui.status("⌨️ Keyboard shortcuts enabled: Ctrl+N to start new transcript")
    }

    // Start keyboard monitoring task
    let keyboardMonitorTask = startKeyboardMonitoring(
        transcriptProcessor: transcriptProcessor,
        terminalProcessor: terminalProcessor,
        ui: ui
    )

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
        remoteFrenchRecognizer: remoteFrenchRecognizer,
        keyboardMonitorTask: keyboardMonitorTask,
        originalTermios: originalTermios
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
