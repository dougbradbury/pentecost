import Foundation

/// UI component for audio device setup and selection
@available(macOS 26.0, *)
struct AudioSetupUI {
    private let audioService: AudioEngineService

    init(audioService: AudioEngineService) {
        self.audioService = audioService
    }

    /// Run the complete audio device selection process
    func runDeviceSelection() async throws {
        print("🎤 Audio Device Selection")
        print(String(repeating: "=", count: 50))

        // Get devices from the audio service
        let inputDevices = try audioService.getInputDevices()
        let outputDevices = try audioService.getOutputDevices()

        guard !inputDevices.isEmpty else {
            print("❌ No input devices found")
            throw AudioSetupError.noInputDevices
        }

        guard !outputDevices.isEmpty else {
            print("❌ No output devices found")
            throw AudioSetupError.noOutputDevices
        }

        // Display device lists
        displayDevices(inputDevices: inputDevices, outputDevices: outputDevices)

        // Select input device
        let selectedInputDevice = try await selectInputDevice(from: inputDevices)
        try audioService.setInputDevice(selectedInputDevice)
        print("🎯 Input: Using \(selectedInputDevice.description)")

        // Select output device
        let selectedOutputDevice = try await selectOutputDevice(from: outputDevices)
        try audioService.setOutputDevice(selectedOutputDevice)
        print("🎯 Output: Using \(selectedOutputDevice.description)")
    }

    // MARK: - Private Methods

    private func displayDevices(inputDevices: [AudioDevice], outputDevices: [AudioDevice]) {
        print("📋 All available audio devices:")
        print("")

        // Display input devices
        print("🎤 INPUT DEVICES:")
        for (index, device) in inputDevices.enumerated() {
            let prefix = device.isDefaultInput ? "👑" : "  "
            print("\(prefix)\(index + 1). \(device.description)")
        }

        print("")

        // Display output devices
        print("🔊 OUTPUT DEVICES:")
        for (index, device) in outputDevices.enumerated() {
            let prefix = device.isDefaultOutput ? "👑" : "  "
            print("\(prefix)\(index + 1). \(device.description)")
        }
    }

    private func selectInputDevice(from devices: [AudioDevice]) async throws -> AudioDevice {
        print("\n🎤 Select INPUT device (1-\(devices.count), or press Enter for default): ", terminator: "")

        if let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if input.isEmpty {
                // Use default device
                return devices.first { $0.isDefaultInput } ?? devices[0]
            } else if let deviceIndex = Int(input), deviceIndex >= 1, deviceIndex <= devices.count {
                // Use selected device
                return devices[deviceIndex - 1]
            } else {
                print("❌ Invalid input selection. Using default device.")
                return devices.first { $0.isDefaultInput } ?? devices[0]
            }
        } else {
            // Fallback to default if no input
            return devices.first { $0.isDefaultInput } ?? devices[0]
        }
    }

    private func selectOutputDevice(from devices: [AudioDevice]) async throws -> AudioDevice {
        print("\n🔊 Select OUTPUT device (1-\(devices.count), or press Enter for default): ", terminator: "")

        if let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if input.isEmpty {
                // Use default device
                return devices.first { $0.isDefaultOutput } ?? devices[0]
            } else if let deviceIndex = Int(input), deviceIndex >= 1, deviceIndex <= devices.count {
                // Use selected device
                return devices[deviceIndex - 1]
            } else {
                print("❌ Invalid output selection. Using default device.")
                return devices.first { $0.isDefaultOutput } ?? devices[0]
            }
        } else {
            // Fallback to default if no input
            return devices.first { $0.isDefaultOutput } ?? devices[0]
        }
    }
}

// MARK: - Error Types

enum AudioSetupError: Error, LocalizedError {
    case noInputDevices
    case noOutputDevices

    var errorDescription: String? {
        switch self {
        case .noInputDevices:
            return "No input devices available"
        case .noOutputDevices:
            return "No output devices available"
        }
    }
}