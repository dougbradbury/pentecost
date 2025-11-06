import Foundation
import SwiftUI
@preconcurrency import AVFoundation
@preconcurrency import Speech
import Translation
import PentecostCore

@available(macOS 26.0, *)
@MainActor
class PentecostViewModel: ObservableObject {
    @Published var localMessages: [TranscriptionMessage] = []
    @Published var remoteMessages: [TranscriptionMessage] = []
    @Published var statusMessage: String = "Ready to start"
    @Published var isRunning: Bool = false
    @Published var selectedLocalDevice: String = "Not selected"
    @Published var selectedRemoteDevice: String = "Not selected"
    @Published var localDeviceFormat: String = ""
    @Published var remoteDeviceFormat: String = ""
    @Published var availableDevices: [AudioDevice] = []
    @Published var selectedLocalDeviceID: AudioDeviceID?
    @Published var selectedRemoteDeviceID: AudioDeviceID?

    private var audioService: AudioEngineService?
    private var inputAudioEngine: AVAudioEngine?
    private var remoteAudioEngine: AVAudioEngine?

    private var inputEnglishRecognizer: SingleLanguageSpeechRecognizer?
    private var inputFrenchRecognizer: SingleLanguageSpeechRecognizer?
    private var remoteEnglishRecognizer: SingleLanguageSpeechRecognizer?
    private var remoteFrenchRecognizer: SingleLanguageSpeechRecognizer?

    private var fileLogger: FileLogger?

    init() {
        do {
            fileLogger = try FileLogger()
        } catch {
            print("⚠️ Failed to initialize file logger: \(error)")
        }
        loadAvailableDevices()
    }

    func loadAvailableDevices() {
        let deviceManager = AudioDeviceManager()
        availableDevices = (try? deviceManager.getInputDevices()) ?? []

        // Set defaults to first two devices if available
        if availableDevices.count > 0 {
            selectedLocalDeviceID = availableDevices[0].deviceID
        }
        if availableDevices.count > 1 {
            selectedRemoteDeviceID = availableDevices[1].deviceID
        }
    }

    func start() async {
        statusMessage = "🔐 Checking permissions..."

        // Request permissions (these need to run without MainActor to avoid crashes)
        let speechAuth = await Self.requestSpeechPermission()

        guard speechAuth == .authorized else {
            statusMessage = "❌ Speech recognition not authorized"
            return
        }

        let micPermission = await Self.requestMicrophonePermission()

        guard micPermission else {
            statusMessage = "❌ Microphone permission denied"
            return
        }


        statusMessage = "✅ Permissions granted"
        fileLogger?.log("✅ All permissions granted")

        // Initialize audio service
        let audioService = AudioEngineService()
        self.audioService = audioService

        // Create UI and processor interfaces
        let ui = GUIUserInterface(viewModel: self)

        // Create processors
        let localProcessor = GUILocalSpeechProcessor(viewModel: self)
        let remoteProcessor = GUIRemoteSpeechProcessor(viewModel: self)

        // Device selection
        statusMessage = "🎤 Setting up audio devices..."
        let deviceSelector = GUIDeviceSelector(viewModel: self)
        let audioSetupCoordinator = AudioSetupCoordinator(
            audioService: audioService,
            deviceSelector: deviceSelector,
            ui: ui
        )

        do {
            try await audioSetupCoordinator.runDeviceSelection()
            fileLogger?.log("✅ Audio devices selected")
        } catch {
            fileLogger?.log("❌ Audio setup failed: \(error)")
            statusMessage = "❌ Audio setup failed: \(error)"
            return
        }

        // Set up input recognition
        statusMessage = "🎙️ Setting up local recognition..."
        fileLogger?.log("🎙️ Setting up LOCAL (microphone) recognition...")

        guard let result = await PentecostViewModel.setupInputRecognition(
            ui: ui,
            speechProcessor: localProcessor,
            audioService: audioService
        ) else {
            fileLogger?.log("❌ LOCAL recognition setup failed")
            statusMessage = "❌ Local recognition setup failed"
            return
        }

        self.inputEnglishRecognizer = result.englishRecognizer
        self.inputFrenchRecognizer = result.frenchRecognizer
        self.inputAudioEngine = result.audioEngine

        fileLogger?.log("✅ LOCAL recognition active")

        // Delay before remote setup
        statusMessage = "⏳ Pausing before remote audio setup..."
        try? await Task.sleep(for: .milliseconds(1500))

        // Set up remote recognition
        statusMessage = "🔊 Setting up remote recognition..."
        fileLogger?.log("🔊 Setting up REMOTE (system audio) recognition...")

        guard let remoteResult = await PentecostViewModel.setupRemoteRecognition(
            ui: ui,
            speechProcessor: remoteProcessor,
            audioService: audioService
        ) else {
            fileLogger?.log("❌ REMOTE recognition setup failed")
            statusMessage = "❌ Remote recognition setup failed"
            return
        }

        self.remoteEnglishRecognizer = remoteResult.englishRecognizer
        self.remoteFrenchRecognizer = remoteResult.frenchRecognizer
        self.remoteAudioEngine = remoteResult.audioEngine

        fileLogger?.log("✅ REMOTE recognition active")

        isRunning = true
        statusMessage = "🎙️ Recording... Speak now!"
    }

    func stop() async {
        statusMessage = "🛑 Stopping..."

        inputAudioEngine?.stop()
        remoteAudioEngine?.stop()

        inputAudioEngine?.inputNode.removeTap(onBus: 0)
        remoteAudioEngine?.inputNode.removeTap(onBus: 0)

        try? await Task.sleep(for: .milliseconds(100))

        // Finish transcription
        do {
            try await inputEnglishRecognizer?.finishTranscribing()
            try await inputFrenchRecognizer?.finishTranscribing()
            try await remoteEnglishRecognizer?.finishTranscribing()
            try await remoteFrenchRecognizer?.finishTranscribing()
        } catch {
            fileLogger?.log("⚠️ Error during transcription cleanup: \(error)")
        }

        isRunning = false
        statusMessage = "✅ Stopped"
        fileLogger?.log("✅ Stopped successfully")
    }

    func clearTranscripts() {
        localMessages.removeAll()
        remoteMessages.removeAll()
    }

    func openLogsFolder() {
        let logsPath = FileManager.default.currentDirectoryPath + "/logs"
        NSWorkspace.shared.open(URL(fileURLWithPath: logsPath))
    }

    func addMessage(_ message: TranscriptionMessage) {
        if message.isLocal {
            // Remove any previous message with same timestamp to avoid duplicates
            localMessages.removeAll { $0.timestamp == message.timestamp && $0.text == message.text }
            localMessages.append(message)
        } else {
            remoteMessages.removeAll { $0.timestamp == message.timestamp && $0.text == message.text }
            remoteMessages.append(message)
        }

        // Translate message in background
        Task {
            await translateMessage(message)
        }
    }

    func translateMessage(_ message: TranscriptionMessage) async {
        do {
            let sourceLanguage = Locale.Language(identifier: message.isEnglish ? "en" : "fr")
            let targetLanguage = Locale.Language(identifier: message.isEnglish ? "fr" : "en")

            let session = TranslationSession(installedSource: sourceLanguage, target: targetLanguage)
            let response = try await session.translate(message.text)

            // Update message with translation
            updateMessageWithTranslation(id: message.id, translation: response.targetText)
        } catch {
            print("❌ Translation failed: \(error)")
        }
    }

    func updateMessageWithTranslation(id: UUID, translation: String) {
        // Update in local messages
        if let index = localMessages.firstIndex(where: { $0.id == id }) {
            let message = localMessages[index]
            localMessages[index] = TranscriptionMessage(
                id: message.id,
                timestamp: message.timestamp,
                text: message.text,
                translation: translation,
                isEnglish: message.isEnglish,
                isLocal: message.isLocal
            )
        }
        // Update in remote messages
        else if let index = remoteMessages.firstIndex(where: { $0.id == id }) {
            let message = remoteMessages[index]
            remoteMessages[index] = TranscriptionMessage(
                id: message.id,
                timestamp: message.timestamp,
                text: message.text,
                translation: translation,
                isEnglish: message.isEnglish,
                isLocal: message.isLocal
            )
        }
    }

    // MARK: - Permission Helpers (nonisolated to avoid actor issues)

    nonisolated static func requestSpeechPermission() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    nonisolated static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // Static versions of setup functions from main.swift
    nonisolated static func setupInputRecognition(
        ui: UserInterface,
        speechProcessor: SpeechProcessor,
        audioService: AudioEngineService
    ) async -> (englishRecognizer: SingleLanguageSpeechRecognizer, frenchRecognizer: SingleLanguageSpeechRecognizer, audioEngine: AVAudioEngine)? {
        do {
            ui.status("🔧 Creating English recognizer...")
            let englishRecognizer = SingleLanguageSpeechRecognizer(ui: ui, speechProcessor: speechProcessor, locale: "en-US")

            ui.status("🔧 Setting up English transcriber...")
            try await englishRecognizer.setUpTranscriber()

            ui.status("⏳ Waiting before French setup...")
            try await Task.sleep(for: .milliseconds(1000))

            ui.status("🔧 Creating French recognizer...")
            let frenchRecognizer = SingleLanguageSpeechRecognizer(ui: ui, speechProcessor: speechProcessor, locale: "fr-CA")

            ui.status("🔧 Setting up French transcriber...")
            try await frenchRecognizer.setUpTranscriber()

            let audioEngine = try audioService.createFirstAudioEngine()

            if let device = audioService.getFirstInputDevice() {
                let deviceName = device.name
                ui.status("✅ LOCAL device: \(deviceName)")
                await MainActor.run {
                    if let viewModel = (ui as? GUIUserInterface)?.viewModel {
                        viewModel.selectedLocalDevice = deviceName
                    }
                }
            }

            let inputNode = audioEngine.inputNode

            // Use the device's output format instead of hardcoded sample rate
            let deviceFormat = inputNode.outputFormat(forBus: 0)
            print("🔍 LOCAL device format: \(deviceFormat)")
            print("🔍 Sample rate: \(deviceFormat.sampleRate)Hz, Channels: \(deviceFormat.channelCount)")

            guard let tapFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                               sampleRate: deviceFormat.sampleRate,
                                               channels: 1,
                                               interleaved: false) else {
                throw AudioError.formatError("Failed to create tap audio format")
            }
            await MainActor.run {
                if let viewModel = (ui as? GUIUserInterface)?.viewModel {
                    viewModel.localDeviceFormat = "\(Int(deviceFormat.sampleRate))Hz, \(deviceFormat.channelCount)ch"
                }
            }

            ui.status("🔌 Installing LOCAL audio tap...")
            nonisolated(unsafe) let englishRef = englishRecognizer
            nonisolated(unsafe) let frenchRef = frenchRecognizer
            var bufferCount = 0
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { buffer, _ in
                bufferCount += 1
                if bufferCount % 100 == 0 {
                    print("🎤 LOCAL: Captured \(bufferCount) audio buffers")
                }
                Task {
                    do {
                        try await englishRef.streamAudioToTranscriber(buffer)
                        try await frenchRef.streamAudioToTranscriber(buffer)
                    } catch {
                        print("❌ Error streaming LOCAL audio: \(error)")
                    }
                }
            }

            try audioEngine.start()
            print("✅ LOCAL audio engine started successfully")
            print("✅ Input node: \(inputNode)")
            print("✅ Is running: \(audioEngine.isRunning)")
            ui.status("🎤 LOCAL audio capture active!")

            return (englishRecognizer, frenchRecognizer, audioEngine)
        } catch {
            ui.status("❌ LOCAL audio setup error: \(error)")
            return nil
        }
    }

    nonisolated static func setupRemoteRecognition(
        ui: UserInterface,
        speechProcessor: SpeechProcessor,
        audioService: AudioEngineService
    ) async -> (englishRecognizer: SingleLanguageSpeechRecognizer, frenchRecognizer: SingleLanguageSpeechRecognizer, audioEngine: AVAudioEngine)? {
        do {
            ui.status("🔧 Creating English recognizer for REMOTE...")
            let englishRecognizer = SingleLanguageSpeechRecognizer(ui: ui, speechProcessor: speechProcessor, locale: "en-US")

            ui.status("🔧 Setting up English transcriber for REMOTE...")
            try await englishRecognizer.setUpTranscriber()

            ui.status("⏳ Waiting before French setup for REMOTE...")
            try await Task.sleep(for: .milliseconds(1000))

            ui.status("🔧 Creating French recognizer for REMOTE...")
            let frenchRecognizer = SingleLanguageSpeechRecognizer(ui: ui, speechProcessor: speechProcessor, locale: "fr-CA")

            ui.status("🔧 Setting up French transcriber for REMOTE...")
            try await frenchRecognizer.setUpTranscriber()

            let audioEngine = try audioService.createSecondAudioEngine()

            if let device = audioService.getSecondInputDevice() {
                let deviceName = device.name
                ui.status("✅ REMOTE device: \(deviceName)")
                await MainActor.run {
                    if let viewModel = (ui as? GUIUserInterface)?.viewModel {
                        viewModel.selectedRemoteDevice = deviceName
                    }
                }
            }

            let inputNode = audioEngine.inputNode

            guard let tapFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 1, interleaved: false) else {
                throw AudioError.formatError("Failed to create tap audio format")
            }

            ui.status("🔌 Installing REMOTE audio tap...")
            nonisolated(unsafe) let englishRef = englishRecognizer
            nonisolated(unsafe) let frenchRef = frenchRecognizer
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { buffer, _ in
                Task {
                    do {
                        try await englishRef.streamAudioToTranscriber(buffer)
                        try await frenchRef.streamAudioToTranscriber(buffer)
                    } catch {
                        print("❌ Error streaming REMOTE audio: \(error)")
                    }
                }
            }

            try audioEngine.start()
            ui.status("🔊 REMOTE audio capture active!")

            return (englishRecognizer, frenchRecognizer, audioEngine)
        } catch {
            ui.status("❌ REMOTE audio setup error: \(error)")
            return nil
        }
    }
}

// MARK: - GUI Adapters

@available(macOS 26.0, *)
final class GUIUserInterface: @unchecked Sendable, UserInterface {
    weak var viewModel: PentecostViewModel?

    init(viewModel: PentecostViewModel) {
        self.viewModel = viewModel
    }

    func status(_ message: String) {
        Task { @MainActor in
            viewModel?.statusMessage = message
        }
    }
}

@available(macOS 26.0, *)
final class GUILocalSpeechProcessor: @unchecked Sendable, SpeechProcessor {
    weak var viewModel: PentecostViewModel?
    private var lastProcessedText: [String: Double] = [:]

    init(viewModel: PentecostViewModel) {
        self.viewModel = viewModel
    }

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String) async {
        print("📝 LOCAL: text='\(text)', isFinal=\(isFinal), locale=\(locale)")
        guard isFinal, !text.isEmpty else { return }

        // Deduplicate using text and timestamp
        let key = "\(text)-\(startTime)"
        if let lastTime = lastProcessedText[key], Date().timeIntervalSince1970 - lastTime < 1.0 {
            print("⏭️ LOCAL: Skipping duplicate")
            return
        }
        lastProcessedText[key] = Date().timeIntervalSince1970

        let isEnglish = locale.hasPrefix("en")

        print("✅ LOCAL: Adding message to UI")
        Task { @MainActor in
            let message = TranscriptionMessage(
                text: text,
                translation: nil,
                isEnglish: isEnglish,
                isLocal: true
            )
            viewModel?.addMessage(message)
        }
    }
}

@available(macOS 26.0, *)
final class GUIRemoteSpeechProcessor: @unchecked Sendable, SpeechProcessor {
    weak var viewModel: PentecostViewModel?
    private var lastProcessedText: [String: Double] = [:]

    init(viewModel: PentecostViewModel) {
        self.viewModel = viewModel
    }

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String) async {
        print("📝 REMOTE: text='\(text)', isFinal=\(isFinal), locale=\(locale)")
        guard isFinal, !text.isEmpty else { return }

        // Deduplicate
        let key = "\(text)-\(startTime)"
        if let lastTime = lastProcessedText[key], Date().timeIntervalSince1970 - lastTime < 1.0 {
            print("⏭️ REMOTE: Skipping duplicate")
            return
        }
        lastProcessedText[key] = Date().timeIntervalSince1970

        let isEnglish = locale.hasPrefix("en")

        print("✅ REMOTE: Adding message to UI")
        Task { @MainActor in
            let message = TranscriptionMessage(
                text: text,
                translation: nil,
                isEnglish: isEnglish,
                isLocal: false
            )
            viewModel?.addMessage(message)
        }
    }
}

@available(macOS 26.0, *)
final class GUIDeviceSelector: @unchecked Sendable, DeviceSelector {
    weak var viewModel: PentecostViewModel?

    init(viewModel: PentecostViewModel? = nil) {
        self.viewModel = viewModel
    }

    func displayInputDevices(_ devices: [AudioDevice]) async {
        // GUI doesn't need to display list
    }

    func selectFirstInputDevice(from devices: [AudioDevice]) async throws -> AudioDevice {
        // Use the device selected in the ViewModel if available
        if let viewModel = await MainActor.run(body: { viewModel }),
           let selectedID = await MainActor.run(body: { viewModel.selectedLocalDeviceID }),
           let device = devices.first(where: { $0.deviceID == selectedID }) {
            return device
        }

        // Fallback to first device
        guard let first = devices.first else {
            throw AudioError.deviceError("No input devices available")
        }
        return first
    }

    func selectSecondInputDevice(from devices: [AudioDevice]) async throws -> AudioDevice {
        // Use the device selected in the ViewModel if available
        if let viewModel = await MainActor.run(body: { viewModel }),
           let selectedID = await MainActor.run(body: { viewModel.selectedRemoteDeviceID }),
           let device = devices.first(where: { $0.deviceID == selectedID }) {
            return device
        }

        // Fallback to second device
        if devices.count > 1 {
            return devices[1]
        }
        guard let first = devices.first else {
            throw AudioError.deviceError("No output devices available")
        }
        return first
    }
}
