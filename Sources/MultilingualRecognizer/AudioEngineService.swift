import Foundation
import AVFoundation

/// Service that manages audio engine configuration and device selection
@available(macOS 26.0, *)
final class AudioEngineService {
    private let deviceManager = AudioDeviceManager()
    private var audioEngine: AVAudioEngine?
    private var selectedInputDevice: AudioDevice?
    private var selectedOutputDevice: AudioDevice?

    /// Get all available input devices
    func getInputDevices() throws -> [AudioDevice] {
        return try deviceManager.getInputDevices()
    }

    /// Get all available output devices
    func getOutputDevices() throws -> [AudioDevice] {
        return try deviceManager.getOutputDevices()
    }

    /// Get all available audio devices
    func getAllDevices() throws -> [AudioDevice] {
        return try deviceManager.getAllAudioDevices()
    }

    /// Set the current input device
    func setInputDevice(_ device: AudioDevice) throws {
        guard device.hasInput else {
            throw AudioEngineServiceError.deviceHasNoInput
        }

        selectedInputDevice = device

        // If we already have an audio engine, apply the device change immediately
        if let audioEngine = audioEngine {
            try deviceManager.setInputDevice(device, for: audioEngine)
        }
    }

    /// Set the current output device (stored for future recording capability)
    func setOutputDevice(_ device: AudioDevice) throws {
        guard device.hasOutput else {
            throw AudioEngineServiceError.deviceHasNoOutput
        }

        selectedOutputDevice = device
        // Note: Output device setting will be implemented when we add recording
    }

    /// Get the currently selected input device
    func getCurrentInputDevice() -> AudioDevice? {
        return selectedInputDevice
    }

    /// Get the currently selected output device
    func getCurrentOutputDevice() -> AudioDevice? {
        return selectedOutputDevice
    }

    /// Create and configure the audio engine with selected devices
    func createConfiguredAudioEngine() throws -> AVAudioEngine {
        let engine = AVAudioEngine()

        // Apply input device selection if available
        if let inputDevice = selectedInputDevice {
            try deviceManager.setInputDevice(inputDevice, for: engine)
        }

        // Store engine reference for future device changes
        audioEngine = engine

        return engine
    }

    /// Get audio format information for the current input
    func getInputFormat() -> AVAudioFormat? {
        return audioEngine?.inputNode.outputFormat(forBus: 0)
    }
}

// MARK: - Error Types

enum AudioEngineServiceError: Error, LocalizedError {
    case deviceHasNoInput
    case deviceHasNoOutput
    case noAudioEngineConfigured

    var errorDescription: String? {
        switch self {
        case .deviceHasNoInput:
            return "Selected device has no input channels"
        case .deviceHasNoOutput:
            return "Selected device has no output channels"
        case .noAudioEngineConfigured:
            return "No audio engine has been configured"
        }
    }
}