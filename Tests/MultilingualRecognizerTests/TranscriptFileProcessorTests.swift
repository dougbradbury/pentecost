import XCTest
@testable import MultilingualRecognizer
import Foundation

@available(macOS 26.0, *)
final class TranscriptFileProcessorTests: XCTestCase {
    var tempDirectory: URL!
    var processor: TranscriptFileProcessor!

    override func setUp() {
        super.setUp()

        // Create a temporary directory for test transcripts
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Set environment variable to use temp directory
        setenv("MEETING_SUMMARY_DIR", tempDirectory.path, 1)

        processor = TranscriptFileProcessor()
    }

    override func tearDown() {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        // Clear environment variable
        unsetenv("MEETING_SUMMARY_DIR")

        processor = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Recursively find all transcript files in a directory
    private func findTranscriptFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent.contains("transcript_") {
                files.append(fileURL)
            }
        }
        return files
    }

    // MARK: - Basic Functionality Tests

    func testGetCurrentSessionTimestamp() async {
        let timestamp = await processor.getCurrentSessionTimestamp()

        // Verify timestamp format: yyyy-MM-dd_HH-mm-ss
        XCTAssertTrue(timestamp.contains("-"))
        XCTAssertTrue(timestamp.contains("_"))
        XCTAssertEqual(timestamp.count, 19) // e.g., "2025-01-15_14-30-45"
    }

    func testStartNewTranscriptFile() async {
        let originalTimestamp = await processor.getCurrentSessionTimestamp()

        // Wait a tiny bit to ensure timestamp will be different
        try? await Task.sleep(for: .seconds(1))

        let newTimestamp = await processor.startNewTranscriptFile()

        // Verify new timestamp is different
        XCTAssertNotEqual(originalTimestamp, newTimestamp)

        // Verify current timestamp was updated
        let currentTimestamp = await processor.getCurrentSessionTimestamp()
        XCTAssertEqual(currentTimestamp, newTimestamp)
    }

    func testStartNewTranscriptFileCreatesNewFiles() async {
        // Write to initial file
        await processor.process(
            text: "First message",
            isFinal: true,
            startTime: 1.0,
            duration: 0.5,
            alternativeCount: 1,
            locale: "en-US"
        )

        let firstTimestamp = await processor.getCurrentSessionTimestamp()

        // Wait to ensure different timestamp
        try? await Task.sleep(for: .seconds(1))

        // Start new file
        let secondTimestamp = await processor.startNewTranscriptFile()

        // Write to new file
        await processor.process(
            text: "Second message",
            isFinal: true,
            startTime: 2.0,
            duration: 0.5,
            alternativeCount: 1,
            locale: "en-US"
        )

        // Verify both files exist
        let transcriptFiles = findTranscriptFiles(in: tempDirectory)

        // We should have files with both timestamps
        let hasFirstFile = transcriptFiles.contains { $0.lastPathComponent.contains(firstTimestamp) }
        let hasSecondFile = transcriptFiles.contains { $0.lastPathComponent.contains(secondTimestamp) }

        XCTAssertTrue(hasFirstFile, "Should have file with first timestamp")
        XCTAssertTrue(hasSecondFile, "Should have file with second timestamp")
    }

    func testCloseAllFiles() async {
        // Write some data to create open file handles
        await processor.process(
            text: "Test message",
            isFinal: true,
            startTime: 1.0,
            duration: 0.5,
            alternativeCount: 1,
            locale: "en-US"
        )

        await processor.process(
            text: "Message en français",
            isFinal: true,
            startTime: 2.0,
            duration: 0.5,
            alternativeCount: 1,
            locale: "fr-FR"
        )

        // Close all files
        await processor.closeAllFiles()

        // Files should still exist on disk (in weekly directory structure)
        let transcriptFiles = findTranscriptFiles(in: tempDirectory)
        XCTAssertGreaterThan(transcriptFiles.count, 0, "Transcript files should exist after closing")

        // Verify we can write again (new handles should be created)
        await processor.process(
            text: "After close",
            isFinal: true,
            startTime: 3.0,
            duration: 0.5,
            alternativeCount: 1,
            locale: "en-US"
        )
    }

    // MARK: - Multiple Language Tests

    func testStartNewFileHandlesMultipleLanguages() async {
        // Write in both languages to first file
        await processor.process(
            text: "English first",
            isFinal: true,
            startTime: 1.0,
            duration: 0.5,
            alternativeCount: 1,
            locale: "en-US"
        )

        await processor.process(
            text: "Français premier",
            isFinal: true,
            startTime: 2.0,
            duration: 0.5,
            alternativeCount: 1,
            locale: "fr-FR"
        )

        _ = await processor.getCurrentSessionTimestamp()

        // Wait for different timestamp
        try? await Task.sleep(for: .seconds(1))

        // Start new files
        await processor.startNewTranscriptFile()

        // Write in both languages to second file
        await processor.process(
            text: "English second",
            isFinal: true,
            startTime: 3.0,
            duration: 0.5,
            alternativeCount: 1,
            locale: "en-US"
        )

        await processor.process(
            text: "Français deuxième",
            isFinal: true,
            startTime: 4.0,
            duration: 0.5,
            alternativeCount: 1,
            locale: "fr-FR"
        )

        // Should have 4 total files: 2 languages × 2 timestamps
        let allFiles = findTranscriptFiles(in: tempDirectory)

        let enFiles = allFiles.filter { $0.path.contains("en-US") }
        let frFiles = allFiles.filter { $0.path.contains("fr-FR") }

        XCTAssertEqual(enFiles.count, 2, "Should have 2 English transcript files")
        XCTAssertEqual(frFiles.count, 2, "Should have 2 French transcript files")
    }
}
