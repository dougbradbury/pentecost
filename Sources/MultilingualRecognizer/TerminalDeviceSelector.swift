import Foundation

/// Terminal-based implementation of DeviceSelector
@available(macOS 26.0, *)
struct TerminalDeviceSelector: DeviceSelector {

    func displayInputDevices(_ devices: [AudioDevice]) async {
        print("📋 Available input devices:")
        print("")

        // Display input devices
        print("🎤 INPUT DEVICES:")
        for (index, device) in devices.enumerated() {
            let prefix = device.isDefaultInput ? "👑" : "  "
            print("\(prefix)\(index + 1). \(device.description)")
        }
        print("")
    }

    func selectFirstInputDevice(from devices: [AudioDevice]) async throws -> AudioDevice {
        print("🎤 Select FIRST input device (LOCAL/MIC) (1-\(devices.count), or press Enter for default): ", terminator: "")

        // Capture CharacterSet to prevent release-build optimizer from deallocating it prematurely
        let whitespace = CharacterSet.whitespacesAndNewlines
        if let input = readLine()?.trimmingCharacters(in: whitespace) {
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

    func selectSecondInputDevice(from devices: [AudioDevice]) async throws -> AudioDevice {
        print("🔊 Select SECOND input device (REMOTE/SYSTEM) (1-\(devices.count), or press Enter for BlackHole): ", terminator: "")

        // Capture CharacterSet to prevent release-build optimizer from deallocating it prematurely
        let whitespace = CharacterSet.whitespacesAndNewlines
        if let input = readLine()?.trimmingCharacters(in: whitespace) {
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
