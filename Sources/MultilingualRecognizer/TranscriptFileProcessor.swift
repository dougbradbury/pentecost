import Foundation

@available(macOS 26.0, *)
actor TranscriptFileProcessor: SpeechProcessor {
    private let baseDirectory: URL
    private var sessionTimestamp: String
    private var openFiles: [String: FileHandle] = [:]
    private let fileManager = FileManager.default
    private let filenameDateFormatter: DateFormatter

    init() {
        // Read MEETING_SUMMARY_DIR environment variable
        let summaryDirPath = ProcessInfo.processInfo.environment["MEETING_SUMMARY_DIR"]
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Meeting_Recordings")
                .appendingPathComponent("summaries")
                .path

        self.baseDirectory = URL(fileURLWithPath: summaryDirPath)

        // Set up date formatter for filenames
        // Note: This is only used during init and startNewTranscriptFile (not concurrent)
        self.filenameDateFormatter = DateFormatter()
        filenameDateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        // Capture initial session start time for filename timestamp
        self.sessionTimestamp = filenameDateFormatter.string(from: Date())
    }

    deinit {
        // Close all open file handles
        for handle in openFiles.values {
            try? handle.close()
        }
    }

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String, source: String) async {
        // Only process final messages
        guard isFinal else { return }

        // Skip empty text
        guard !text.isEmpty else { return }

        do {
            let fileHandle = try getFileHandle(for: locale)

            // Use actual system time instead of relative recording time
            let now = Date()

            // DateFormatter is not thread-safe, so create fresh instances per call
            // This avoids race conditions when multiple recognizers call process() simultaneously
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            let timestamp = formatter.string(from: now)

            // Calculate end time by adding duration
            let endDate = now.addingTimeInterval(duration)
            let endTime = formatter.string(from: endDate)

            // Prefix with source label (LOCAL or REMOTE)
            let sourceLabel = source.uppercased()
            let entry = "[\(sourceLabel)] \(timestamp) - \(endTime): \(text)\n"

            if let data = entry.data(using: .utf8) {
                try fileHandle.write(contentsOf: data)
            }
        } catch {
            print("Error writing to transcript file for \(locale): \(error)")
        }
    }

    private func getFileHandle(for locale: String) throws -> FileHandle {
        if let existing = openFiles[locale] {
            return existing
        }

        // Get current weekly directory and create transcripts subdirectory
        let weeklyDirectory = getWeeklyDirectory()
        let transcriptsDirectory = weeklyDirectory.appendingPathComponent("transcripts")

        // Create directories if they don't exist
        try fileManager.createDirectory(at: transcriptsDirectory, withIntermediateDirectories: true)

        let filename = "transcript_\(sessionTimestamp)_\(locale).txt"
        let fileURL = transcriptsDirectory.appendingPathComponent(filename)

        // Create file if it doesn't exist
        if !fileManager.fileExists(atPath: fileURL.path) {
            let header = "# Transcript for \(locale)\n# Format: [YYYY-MM-DD HH:mm:ss.SSS] - [YYYY-MM-DD HH:mm:ss.SSS]: [text]\n\n"
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

    // MARK: - Public API

    /// Start a new transcript file with a fresh timestamp
    /// Closes existing file handles and creates new files for subsequent writes
    /// - Returns: The new session timestamp used for the filename
    @discardableResult
    func startNewTranscriptFile() -> String {
        // Close all existing file handles
        closeAllFiles()

        // Generate new session timestamp
        let newTimestamp = filenameDateFormatter.string(from: Date())
        sessionTimestamp = newTimestamp

        return newTimestamp
    }

    /// Close all currently open transcript files and mark them as finished
    func closeAllFiles() {
        // Add FINISHED tag to all open files before closing
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let finishTime = formatter.string(from: Date())
        let finishTag = "\n\n# FINISHED: \(finishTime)\n"

        for (locale, handle) in openFiles {
            do {
                // Write FINISHED tag
                if let tagData = finishTag.data(using: .utf8) {
                    try handle.write(contentsOf: tagData)
                }

                try handle.synchronize() // Flush to disk
                try handle.close()
            } catch {
                print("Error closing transcript file for \(locale): \(error)")
            }
        }
        openFiles.removeAll()
    }

    /// Get the current session timestamp
    func getCurrentSessionTimestamp() -> String {
        return sessionTimestamp
    }

    /// Get the path to the current transcript file for a specific locale
    /// - Parameter locale: The locale identifier (e.g., "en-US")
    /// - Returns: Full path to the transcript file, or nil if no file exists yet
    func getCurrentTranscriptPath(for locale: String = "en-US") -> String? {
        let weeklyDirectory = getWeeklyDirectory()
        let transcriptsDirectory = weeklyDirectory.appendingPathComponent("transcripts")
        let filename = "transcript_\(sessionTimestamp)_\(locale).txt"
        let fileURL = transcriptsDirectory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL.path
        }
        return nil
    }
}