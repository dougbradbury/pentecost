import Foundation

@available(macOS 26.0, *)
final class TranscriptFileProcessor: @unchecked Sendable, SpeechProcessor {
    private let outputDirectory: URL
    private var openFiles: [String: FileHandle] = [:]
    private let fileManager = FileManager.default

    init(outputDirectory: URL = URL(fileURLWithPath: "transcripts")) {
        self.outputDirectory = outputDirectory

        // Create output directory if it doesn't exist
        try? fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    deinit {
        // Close all open file handles
        for handle in openFiles.values {
            try? handle.close()
        }
    }

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String) async {
        // Only process final messages
        guard isFinal else { return }

        // Skip empty text
        guard !text.isEmpty else { return }

        do {
            let fileHandle = try await getFileHandle(for: locale)
            let timestamp = formatTimestamp(startTime)
            let endTime = formatTimestamp(startTime + duration)
            let entry = "\(timestamp) - \(endTime): \(text)\n"

            if let data = entry.data(using: .utf8) {
                try fileHandle.write(contentsOf: data)
            }
        } catch {
            print("Error writing to transcript file for \(locale): \(error)")
        }
    }

    private func getFileHandle(for locale: String) async throws -> FileHandle {
        if let existing = openFiles[locale] {
            return existing
        }

        let filename = "transcript_\(locale).txt"
        let fileURL = outputDirectory.appendingPathComponent(filename)

        // Create file if it doesn't exist
        if !fileManager.fileExists(atPath: fileURL.path) {
            let header = "# Transcript for \(locale)\n# Format: [start] - [end]: [text]\n\n"
            try header.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let fileHandle = try FileHandle(forWritingTo: fileURL)
        try fileHandle.seekToEnd()

        openFiles[locale] = fileHandle
        return fileHandle
    }

    private func formatTimestamp(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = time.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%05.2f", minutes, seconds)
    }
}