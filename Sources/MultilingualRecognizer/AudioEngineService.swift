import Foundation
import AVFoundation

/// Service that manages audio engine configuration and device selection
@available(macOS 26.0, *)
final class AudioEngineService {
    private let deviceManager = AudioDeviceManager()
    private var firstInputDevice: AudioDevice?
    private var secondInputDevice: AudioDevice?

    /// Get all available input devices
    func getInputDevices() throws -> [AudioDevice] {
        return try deviceManager.getInputDevices()
    }

    /// Set the first input device (local microphone)
    func setFirstInputDevice(_ device: AudioDevice) throws {
        guard device.hasInput else {
            throw AudioEngineServiceError.deviceHasNoInput
        }
        firstInputDevice = device
    }

    /// Set the second input device (remote/system audio)
    func setSecondInputDevice(_ device: AudioDevice) throws {
        guard device.hasInput else {
            throw AudioEngineServiceError.deviceHasNoInput
        }
        secondInputDevice = device
    }

    /// Get the first input device (local microphone)
    func getFirstInputDevice() -> AudioDevice? {
        return firstInputDevice
    }

    /// Get the second input device (remote/system audio)
    func getSecondInputDevice() -> AudioDevice? {
        return secondInputDevice
    }

    /// Create audio engine configured with the first input device (local)
    func createFirstAudioEngine() async throws -> AVAudioEngine {
        let engine = AVAudioEngine()

        if let device = firstInputDevice {
            try await deviceManager.setInputDevice(device, for: engine)
        }

        return engine
    }

    /// Create audio engine configured with the second input device (remote)
    func createSecondAudioEngine() async throws -> AVAudioEngine {
        let engine = AVAudioEngine()

        if let device = secondInputDevice {
            try await deviceManager.setInputDevice(device, for: engine)
        }

        return engine
    }
}

// MARK: - Error Types

enum AudioEngineServiceError: Error, LocalizedError {
    case deviceHasNoInput

    var errorDescription: String? {
        switch self {
        case .deviceHasNoInput:
            return "Selected device has no input channels"
        }
    }
}