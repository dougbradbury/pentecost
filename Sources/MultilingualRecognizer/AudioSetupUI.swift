import Foundation

/// UI component for audio device setup and selection
@available(macOS 26.0, *)
struct AudioSetupUI {
    private let audioService: AudioEngineService

    init(audioService: AudioEngineService) {
        self.audioService = audioService
    }

    /// Run the complete dual input device selection process
    func runDeviceSelection() async throws {
        print("🎤 Dual Input Device Selection")
        print(String(repeating: "=", count: 50))

        // Get input devices from the audio service
        let inputDevices = try audioService.getInputDevices()

        guard !inputDevices.isEmpty else {
            print("❌ No input devices found")
            throw AudioSetupError.noInputDevices
        }

        // Display input devices
        displayInputDevices(inputDevices: inputDevices)

        // Select first input device (local microphone)
        let firstInputDevice = try await selectFirstInputDevice(from: inputDevices)
        try audioService.setFirstInputDevice(firstInputDevice)
        print("🎯 LOCAL (Mic): Using \(firstInputDevice.description)")

        // Select second input device (remote/system audio)
        let secondInputDevice = try await selectSecondInputDevice(from: inputDevices)
        try audioService.setSecondInputDevice(secondInputDevice)
        print("🎯 REMOTE (System): Using \(secondInputDevice.description)")
    }

    // MARK: - Private Methods

    private func displayInputDevices(inputDevices: [AudioDevice]) {
        print("📋 Available input devices:")
        print("")

        // Display input devices
        print("🎤 INPUT DEVICES:")
        for (index, device) in inputDevices.enumerated() {
            let prefix = device.isDefaultInput ? "👑" : "  "
            print("\(prefix)\(index + 1). \(device.description)")
        }
        print("")
    }

    private func selectFirstInputDevice(from devices: [AudioDevice]) async throws -> AudioDevice {
        print("🎤 Select FIRST input device (LOCAL/MIC) (1-\(devices.count), or press Enter for default): ", terminator: "")

        if let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if input.isEmpty {
                // Use default device
                return devices.first { $0.isDefaultInput } ?? devices[0]
            } else if let deviceIndex = Int(input), deviceIndex >= 1, deviceIndex <= devices.count {
                // Use selected device
                return devices[deviceIndex - 1]
            } else {
                print("❌ Invalid selection. Using default device.")
                return devices.first { $0.isDefaultInput } ?? devices[0]
            }
        } else {
            // Fallback to default if no input
            return devices.first { $0.isDefaultInput } ?? devices[0]
        }
    }

    private func selectSecondInputDevice(from devices: [AudioDevice]) async throws -> AudioDevice {
        print("🔊 Select SECOND input device (REMOTE/SYSTEM) (1-\(devices.count), or press Enter for BlackHole): ", terminator: "")

        if let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if input.isEmpty {
                // Try to find BlackHole as default for second input
                return devices.first { $0.name.contains("BlackHole") } ?? devices[0]
            } else if let deviceIndex = Int(input), deviceIndex >= 1, deviceIndex <= devices.count {
                // Use selected device
                return devices[deviceIndex - 1]
            } else {
                print("❌ Invalid selection. Using BlackHole or first device.")
                return devices.first { $0.name.contains("BlackHole") } ?? devices[0]
            }
        } else {
            // Fallback to BlackHole if available
            return devices.first { $0.name.contains("BlackHole") } ?? devices[0]
        }
    }
}

// MARK: - Error Types

enum AudioSetupError: Error, LocalizedError {
    case noInputDevices

    var errorDescription: String? {
        switch self {
        case .noInputDevices:
            return "No input devices available"
        }
    }
}