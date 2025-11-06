import Foundation
import SwiftUI
@preconcurrency import AVFoundation
@preconcurrency import Speech
import PentecostCore

@available(macOS 26.0, *)
@MainActor
class PentecostViewModel: ObservableObject {
    @Published var localMessages: [TranscriptionMessage] = []
    @Published var remoteMessages: [TranscriptionMessage] = []
    @Published var statusMessage: String = "Ready to start"
    @Published var isRunning: Bool = false
    
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
        let deviceSelector = GUIDeviceSelector()
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
                ui.status("✅ LOCAL device: \(device.name)")
            }
            
            let inputNode = audioEngine.inputNode
            
            guard let tapFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 1, interleaved: false) else {
                throw AudioError.formatError("Failed to create tap audio format")
            }
            
            ui.status("🔌 Installing LOCAL audio tap...")
            nonisolated(unsafe) let englishRef = englishRecognizer
            nonisolated(unsafe) let frenchRef = frenchRecognizer
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { buffer, _ in
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
            ui.status("🎙️ LOCAL audio capture active!")
            
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
                ui.status("✅ REMOTE device: \(device.name)")
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
        guard isFinal, !text.isEmpty else { return }
        
        // Deduplicate using text and timestamp
        let key = "\(text)-\(startTime)"
        if let lastTime = lastProcessedText[key], Date().timeIntervalSince1970 - lastTime < 1.0 {
            return
        }
        lastProcessedText[key] = Date().timeIntervalSince1970
        
        let isEnglish = locale.hasPrefix("en")
        
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
        guard isFinal, !text.isEmpty else { return }
        
        // Deduplicate
        let key = "\(text)-\(startTime)"
        if let lastTime = lastProcessedText[key], Date().timeIntervalSince1970 - lastTime < 1.0 {
            return
        }
        lastProcessedText[key] = Date().timeIntervalSince1970
        
        let isEnglish = locale.hasPrefix("en")
        
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
    func displayInputDevices(_ devices: [AudioDevice]) async {
        // GUI doesn't need to display list
    }
    
    func selectFirstInputDevice(from devices: [AudioDevice]) async throws -> AudioDevice {
        // For GUI, just select the first device (typically built-in mic)
        guard let first = devices.first else {
            throw AudioError.deviceError("No input devices available")
        }
        return first
    }
    
    func selectSecondInputDevice(from devices: [AudioDevice]) async throws -> AudioDevice {
        // Select second device if available (for BlackHole/remote audio)
        if devices.count > 1 {
            return devices[1]
        }
        guard let first = devices.first else {
            throw AudioError.deviceError("No output devices available")
        }
        return first
    }
}
