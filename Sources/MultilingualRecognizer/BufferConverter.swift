import Foundation
@preconcurrency import AVFoundation

// Enhanced buffer converter with error handling
@available(macOS 26.0, *)
final class BufferConverter: Sendable {
    func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        // If formats are the same, return original buffer
        if buffer.format.isEqual(format) {
            return buffer
        }

        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            throw NSError(domain: "ConversionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
        }

        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw NSError(domain: "ConversionError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create converted buffer"])
        }

        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .error, let error = error {
            throw error
        }

        return convertedBuffer
    }
}
