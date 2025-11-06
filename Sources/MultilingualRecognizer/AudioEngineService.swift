import Foundation
import AVFoundation

/// Service that manages audio engine configuration and device selection
@available(macOS 26.0, *)
public final class AudioEngineService {
    private let deviceManager = AudioDeviceManager()
    private var firstInputDevice: AudioDevice?
    private var secondInputDevice: AudioDevice?

    public init() {}
    
    /// Get all available input devices
    public func getInputDevices() throws -> [AudioDevice] {
        return try deviceManager.getInputDevices()
    }

    /// Set the first input device (local microphone)
    public func setFirstInputDevice(_ device: AudioDevice) throws {
        guard device.hasInput else {
            throw AudioEngineServiceError.deviceHasNoInput
        }
        firstInputDevice = device
    }

    /// Set the second input device (remote/system audio)
    public func setSecondInputDevice(_ device: AudioDevice) throws {
        guard device.hasInput else {
            throw AudioEngineServiceError.deviceHasNoInput
        }
        secondInputDevice = device
    }

    /// Get the first input device (local microphone)
    public func getFirstInputDevice() -> AudioDevice? {
        return firstInputDevice
    }

    /// Get the second input device (remote/system audio)
    public func getSecondInputDevice() -> AudioDevice? {
        return secondInputDevice
    }

    /// Create audio engine configured with the first input device (local)
    public func createFirstAudioEngine() throws -> AVAudioEngine {
        let engine = AVAudioEngine()

        if let device = firstInputDevice {
            try deviceManager.setInputDevice(device, for: engine)
        }

        return engine
    }

    /// Create audio engine configured with the second input device (remote)
    public func createSecondAudioEngine() throws -> AVAudioEngine {
        let engine = AVAudioEngine()

        if let device = secondInputDevice {
            try deviceManager.setInputDevice(device, for: engine)
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