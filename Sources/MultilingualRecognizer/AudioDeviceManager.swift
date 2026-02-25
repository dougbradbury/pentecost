import Foundation
import CoreAudio
import AVFoundation

/// Represents an audio device with its properties
struct AudioDevice {
    let deviceID: AudioDeviceID
    let name: String
    let uid: String
    let manufacturer: String
    let hasInput: Bool
    let hasOutput: Bool
    let inputChannels: Int
    let outputChannels: Int
    let isDefaultInput: Bool
    let isDefaultOutput: Bool

    var description: String {
        let type = hasInput && hasOutput ? "I/O" : hasInput ? "Input" : "Output"
        let channels = hasInput ? "(\(inputChannels) in)" : "(\(outputChannels) out)"
        let defaultMark = isDefaultInput ? " [Default Input]" : isDefaultOutput ? " [Default Output]" : ""
        return "\(name) - \(manufacturer) \(type) \(channels)\(defaultMark)"
    }
}

/// Manages audio device enumeration and selection for macOS
@available(macOS 26.0, *)
final class AudioDeviceManager {

    /// Enumerate all available audio devices
    func getAllAudioDevices() throws -> [AudioDevice] {
        var devices: [AudioDevice] = []

        // Get all device IDs
        let deviceIDs = try getAudioDeviceIDs()

        // Get default devices
        let defaultInputID = try getDefaultInputDeviceID()
        let defaultOutputID = try getDefaultOutputDeviceID()

        for deviceID in deviceIDs {
            if let device = try? createAudioDevice(
                deviceID: deviceID,
                defaultInputID: defaultInputID,
                defaultOutputID: defaultOutputID
            ) {
                devices.append(device)
            }
        }

        return devices
    }

    /// Get only input devices (devices with input channels)
    func getInputDevices() throws -> [AudioDevice] {
        return try getAllAudioDevices().filter { $0.hasInput }
    }

    /// Get only output devices (devices with output channels)
    func getOutputDevices() throws -> [AudioDevice] {
        return try getAllAudioDevices().filter { $0.hasOutput }
    }

    /// Set the input device for an AVAudioEngine
    func setInputDevice(_ device: AudioDevice, for audioEngine: AVAudioEngine) async throws {
        guard device.hasInput else {
            throw AudioDeviceError.deviceHasNoInput
        }

        // Retry pattern to handle audio system initialization timing issues
        var lastError: Error?
        var retryCount = 0
        let maxRetries = 5

        while retryCount < maxRetries {
            do {
                // Try to access the input node - this can crash if audio system isn't ready
                let inputNode = audioEngine.inputNode

                // If we got here without crashing, check if audioUnit is available
                guard let inputUnit = inputNode.audioUnit else {
                    throw AudioDeviceError.cannotAccessAudioUnit
                }

                var deviceID = device.deviceID
                let status = AudioUnitSetProperty(
                    inputUnit,
                    kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global,
                    0,
                    &deviceID,
                    UInt32(MemoryLayout<AudioDeviceID>.size)
                )

                if status != noErr {
                    throw AudioDeviceError.failedToSetDevice(status)
                }

                // Success! Exit retry loop
                return

            } catch {
                lastError = error
                retryCount += 1

                if retryCount < maxRetries {
                    // Wait before retrying - exponential backoff
                    try await Task.sleep(for: .milliseconds(100 * retryCount))
                }
            }
        }

        // If we exhausted retries, throw the last error
        throw lastError ?? AudioDeviceError.cannotAccessAudioUnit
    }

    // MARK: - Private Methods

    private func getAudioDeviceIDs() throws -> [AudioDeviceID] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var propertySize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )

        guard status == noErr else {
            throw AudioDeviceError.failedToGetPropertySize(status)
        }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array<AudioDeviceID>(repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )

        guard status == noErr else {
            throw AudioDeviceError.failedToGetPropertyData(status)
        }

        return deviceIDs
    }

    private func getDefaultInputDeviceID() throws -> AudioDeviceID {
        return try getDefaultDeviceID(selector: kAudioHardwarePropertyDefaultInputDevice)
    }

    private func getDefaultOutputDeviceID() throws -> AudioDeviceID {
        return try getDefaultDeviceID(selector: kAudioHardwarePropertyDefaultOutputDevice)
    }

    private func getDefaultDeviceID(selector: AudioObjectPropertySelector) throws -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )

        guard status == noErr else {
            throw AudioDeviceError.failedToGetDefaultDevice(status)
        }

        return deviceID
    }

    private func createAudioDevice(deviceID: AudioDeviceID, defaultInputID: AudioDeviceID, defaultOutputID: AudioDeviceID) throws -> AudioDevice {
        let name = try getDeviceProperty(deviceID: deviceID, selector: kAudioObjectPropertyName) as String
        let uid = try getDeviceProperty(deviceID: deviceID, selector: kAudioDevicePropertyDeviceUID) as String
        let manufacturer = try getDeviceProperty(deviceID: deviceID, selector: kAudioObjectPropertyManufacturer) as String

        let inputChannels = try getChannelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeInput)
        let outputChannels = try getChannelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput)

        return AudioDevice(
            deviceID: deviceID,
            name: name,
            uid: uid,
            manufacturer: manufacturer,
            hasInput: inputChannels > 0,
            hasOutput: outputChannels > 0,
            inputChannels: inputChannels,
            outputChannels: outputChannels,
            isDefaultInput: deviceID == defaultInputID,
            isDefaultOutput: deviceID == defaultOutputID
        )
    }

    private func getDeviceProperty<T>(deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) throws -> T {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var propertySize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize
        )

        guard status == noErr else {
            throw AudioDeviceError.failedToGetPropertySize(status)
        }

        if T.self == String.self {
            // For string properties, allocate memory and handle CFString properly
            let cfStringPtr = UnsafeMutablePointer<CFString?>.allocate(capacity: 1)
            defer { cfStringPtr.deallocate() }
            cfStringPtr.initialize(to: nil)

            status = AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &propertySize,
                cfStringPtr
            )

            guard status == noErr else {
                throw AudioDeviceError.failedToGetPropertyData(status)
            }

            if let cfString = cfStringPtr.pointee {
                let string = cfString as String
                return string as! T
            } else {
                return "Unknown" as! T
            }
        } else {
            let value = UnsafeMutablePointer<T>.allocate(capacity: 1)
            defer { value.deallocate() }

            status = AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &propertySize,
                value
            )

            guard status == noErr else {
                throw AudioDeviceError.failedToGetPropertyData(status)
            }

            return value.pointee
        }
    }

    private func getChannelCount(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) throws -> Int {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var propertySize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize
        )

        guard status == noErr else {
            // If we can't get stream configuration, assume 0 channels
            return 0
        }

        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferList.deallocate() }

        status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            bufferList
        )

        guard status == noErr else {
            return 0
        }

        var channelCount = 0
        let bufferCount = Int(bufferList.pointee.mNumberBuffers)

        for i in 0..<bufferCount {
            let buffer = withUnsafePointer(to: bufferList.pointee.mBuffers) { buffersPtr in
                buffersPtr.advanced(by: i).pointee
            }
            channelCount += Int(buffer.mNumberChannels)
        }

        return channelCount
    }
}

// MARK: - Error Types

enum AudioDeviceError: Error, LocalizedError {
    case failedToGetPropertySize(OSStatus)
    case failedToGetPropertyData(OSStatus)
    case failedToGetDefaultDevice(OSStatus)
    case failedToSetDevice(OSStatus)
    case deviceHasNoInput
    case cannotAccessAudioUnit

    var errorDescription: String? {
        switch self {
        case .failedToGetPropertySize(let status):
            return "Failed to get property size: \(status)"
        case .failedToGetPropertyData(let status):
            return "Failed to get property data: \(status)"
        case .failedToGetDefaultDevice(let status):
            return "Failed to get default device: \(status)"
        case .failedToSetDevice(let status):
            return "Failed to set device: \(status)"
        case .deviceHasNoInput:
            return "Selected device has no input channels"
        case .cannotAccessAudioUnit:
            return "Cannot access audio unit for input node"
        }
    }
}
