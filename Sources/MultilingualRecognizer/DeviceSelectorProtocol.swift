import Foundation

/// Protocol for abstracting device selection UI
protocol DeviceSelector: Sendable {
    /// Display available input devices to the user
    func displayInputDevices(_ devices: [AudioDevice]) async

    /// Select the first input device (local microphone)
    /// - Parameter devices: Available audio devices
    /// - Returns: The selected audio device
    func selectFirstInputDevice(from devices: [AudioDevice]) async throws -> AudioDevice

    /// Select the second input device (remote/system audio)
    /// - Parameter devices: Available audio devices
    /// - Returns: The selected audio device
    func selectSecondInputDevice(from devices: [AudioDevice]) async throws -> AudioDevice
}
