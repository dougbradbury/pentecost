import Foundation

/// Coordinator for audio device setup - UI-independent
/// Orchestrates device selection using injected DeviceSelector
@available(macOS 26.0, *)
struct AudioSetupCoordinator {
    private let audioService: AudioEngineService
    private let deviceSelector: DeviceSelector
    private let ui: UserInterface

    init(audioService: AudioEngineService, deviceSelector: DeviceSelector, ui: UserInterface) {
        self.audioService = audioService
        self.deviceSelector = deviceSelector
        self.ui = ui
    }

    /// Run the complete dual input device selection process
    func runDeviceSelection() async throws {
        ui.status("🎤 Dual Input Device Selection")
        ui.status(String(repeating: "=", count: 50))

        // Get input devices from the audio service
        let inputDevices = try audioService.getInputDevices()

        guard !inputDevices.isEmpty else {
            ui.status("❌ No input devices found")
            throw AudioSetupError.noInputDevices
        }

        // Display input devices via selector
        await deviceSelector.displayInputDevices(inputDevices)

        // Select first input device (local microphone)
        let firstInputDevice = try await deviceSelector.selectFirstInputDevice(from: inputDevices)
        try audioService.setFirstInputDevice(firstInputDevice)
        ui.status("🎯 LOCAL (Mic): Using \(firstInputDevice.description)")

        // Select second input device (remote/system audio)
        let secondInputDevice = try await deviceSelector.selectSecondInputDevice(from: inputDevices)
        try audioService.setSecondInputDevice(secondInputDevice)
        ui.status("🎯 REMOTE (System): Using \(secondInputDevice.description)")
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