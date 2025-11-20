import Foundation

/// Thread-safe file logger that writes logs to disk
@available(macOS 26.0, *)
public final class FileLogger: @unchecked Sendable {
    private let fileHandle: FileHandle
    private let logFilePath: String
    private let dateFormatter: DateFormatter

    public init() throws {
        // Create logs directory in project root
        let projectRoot = FileManager.default.currentDirectoryPath
        let logsDir = URL(fileURLWithPath: projectRoot).appendingPathComponent("logs")

        try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        // Create log file with timestamp
        let timestamp = DateFormatter().then {
            $0.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        }.string(from: Date())

        let logFileName = "pentecost_\(timestamp).log"
        let logFileURL = logsDir.appendingPathComponent(logFileName)

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            let header = "=== Pentecost Log ===\n\(Date())\n\n"
            try header.write(to: logFileURL, atomically: true, encoding: .utf8)
        }

        self.fileHandle = try FileHandle(forWritingTo: logFileURL)
        self.logFilePath = logFileURL.path
        try self.fileHandle.seekToEnd()

        self.dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        print("📝 Logging to: \(logFilePath)")
    }

    deinit {
        try? fileHandle.close()
    }

    public func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let entry = "[\(timestamp)] \(message)\n"

        // Also print to console
        print(entry.trimmingCharacters(in: .newlines))

        // Write to file
        if let data = entry.data(using: .utf8) {
            try? fileHandle.write(contentsOf: data)
        }
    }

    func getLogPath() -> String {
        return logFilePath
    }
}

// Helper extension for cleaner initialization
extension DateFormatter {
    func then(_ block: (DateFormatter) -> Void) -> DateFormatter {
        block(self)
        return self
    }
}

// Global logger instance
@available(macOS 26.0, *)
nonisolated(unsafe) var globalLogger: FileLogger?
