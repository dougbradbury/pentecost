import Foundation

@available(macOS 26.0, *)
final class TranscriptFileProcessor: @unchecked Sendable, SpeechProcessor {
    private let baseDirectory: URL
    private var openFiles: [String: FileHandle] = [:]
    private let fileManager = FileManager.default

    init() {
        // Read MEETING_SUMMARY_DIR environment variable
        let summaryDirPath = ProcessInfo.processInfo.environment["MEETING_SUMMARY_DIR"]
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Meeting_Recordings")
                .appendingPathComponent("summaries")
                .path

        self.baseDirectory = URL(fileURLWithPath: summaryDirPath)
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

        // Get current weekly directory and create transcripts subdirectory
        let weeklyDirectory = getWeeklyDirectory()
        let transcriptsDirectory = weeklyDirectory.appendingPathComponent("transcripts")

        // Create directories if they don't exist
        try fileManager.createDirectory(at: transcriptsDirectory, withIntermediateDirectories: true)

        let filename = "transcript_\(locale).txt"
        let fileURL = transcriptsDirectory.appendingPathComponent(filename)

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

    private func getWeeklyDirectory() -> URL {
        let calendar = Calendar.current
        let now = Date()

        // Calculate the start of the week (Monday)
        let weekday = calendar.component(.weekday, from: now)
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        // We want Monday as start of week
        let daysSinceMonday = (weekday == 1) ? 6 : weekday - 2

        let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: now) ?? now

        // Format the week directory name as "Week_YYYY-MM-DD" (Monday's date)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let weekName = "Week_\(formatter.string(from: monday))"

        return baseDirectory.appendingPathComponent(weekName)
    }

    private func formatTimestamp(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = time.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%05.2f", minutes, seconds)
    }
}