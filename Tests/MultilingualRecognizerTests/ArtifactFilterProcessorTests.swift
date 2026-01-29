import Foundation
import Testing
@testable import MultilingualRecognizer

// Mock processor to verify what gets passed through
@available(macOS 26.0, *)
final class MockSpeechProcessor: SpeechProcessor, @unchecked Sendable {
    var processedTexts: [String] = []
    var processCount: Int = 0

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String, source: String) async {
        processCount += 1
        processedTexts.append(text)
    }
}

@Suite("ArtifactFilterProcessor Tests")
struct ArtifactFilterProcessorTests {

    @Test("Filters out text that is mostly commas")
    @available(macOS 26.0, *)
    func testFiltersCommaOnlyText() async {
        // Given: A processor with a mock next processor
        let mockProcessor = MockSpeechProcessor()
        let artifactFilter = ArtifactFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing text that is only commas and spaces
        await artifactFilter.process(
            text: ", , , , , , , , , , , , , , , , , , , , , ,",
            isFinal: true,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should be filtered out (not passed to next processor)
        #expect(mockProcessor.processCount == 0)
        #expect(mockProcessor.processedTexts.isEmpty)
    }

    @Test("Passes through valid text")
    @available(macOS 26.0, *)
    func testPassesValidText() async {
        // Given: A processor with a mock next processor
        let mockProcessor = MockSpeechProcessor()
        let artifactFilter = ArtifactFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing valid text
        let validText = "Hello, this is a valid sentence."
        await artifactFilter.process(
            text: validText,
            isFinal: true,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should pass through to next processor
        #expect(mockProcessor.processCount == 1)
        #expect(mockProcessor.processedTexts.first == validText)
    }

    @Test("Filters text with high comma ratio")
    @available(macOS 26.0, *)
    func testFiltersHighCommaRatio() async {
        // Given: A processor with a mock next processor
        let mockProcessor = MockSpeechProcessor()
        let artifactFilter = ArtifactFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing text where more than 50% is commas
        await artifactFilter.process(
            text: ",,,,,,a",  // 6 commas, 1 letter = 85% commas
            isFinal: true,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should be filtered out
        #expect(mockProcessor.processCount == 0)
    }

    @Test("Passes text with acceptable comma ratio")
    @available(macOS 26.0, *)
    func testPassesAcceptableCommaRatio() async {
        // Given: A processor with a mock next processor
        let mockProcessor = MockSpeechProcessor()
        let artifactFilter = ArtifactFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing text where less than 50% is commas
        let validText = "Hello, world, how are you"  // 2 commas, 22 letters = ~9% commas
        await artifactFilter.process(
            text: validText,
            isFinal: true,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should pass through
        #expect(mockProcessor.processCount == 1)
        #expect(mockProcessor.processedTexts.first == validText)
    }

    @Test("Filters empty text")
    @available(macOS 26.0, *)
    func testFiltersEmptyText() async {
        // Given: A processor with a mock next processor
        let mockProcessor = MockSpeechProcessor()
        let artifactFilter = ArtifactFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing empty or whitespace-only text
        await artifactFilter.process(
            text: "   ",
            isFinal: true,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should be filtered out
        #expect(mockProcessor.processCount == 0)
    }

    @Test("Handles custom comma threshold")
    @available(macOS 26.0, *)
    func testCustomCommaThreshold() async {
        // Given: A processor with a lower threshold (30%)
        let mockProcessor = MockSpeechProcessor()
        let artifactFilter = ArtifactFilterProcessor(nextProcessor: mockProcessor, commaThreshold: 0.3)

        // When: Processing text with 40% commas
        await artifactFilter.process(
            text: ",,abc",  // 2 commas, 3 letters = 40% commas
            isFinal: true,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should be filtered out (exceeds 30% threshold)
        #expect(mockProcessor.processCount == 0)
    }

    @Test("Filters repetitive word patterns")
    @available(macOS 26.0, *)
    func testFiltersRepetitiveWords() async {
        // Given: A processor with default settings
        let mockProcessor = MockSpeechProcessor()
        let artifactFilter = ArtifactFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing text with the same word repeated many times
        await artifactFilter.process(
            text: ", no, no, no, no, no, no, no, no, no, no, no, no, no,",
            isFinal: true,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should be filtered out
        #expect(mockProcessor.processCount == 0)
    }

    @Test("Passes text with acceptable word repetition")
    @available(macOS 26.0, *)
    func testPassesAcceptableWordRepetition() async {
        // Given: A processor with default settings (threshold = 4)
        let mockProcessor = MockSpeechProcessor()
        let artifactFilter = ArtifactFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing text with 3 repetitions (below threshold)
        let validText = "no, no, no, but yes"
        await artifactFilter.process(
            text: validText,
            isFinal: true,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should pass through
        #expect(mockProcessor.processCount == 1)
        #expect(mockProcessor.processedTexts.first == validText)
    }

    @Test("Filters different repetitive words")
    @available(macOS 26.0, *)
    func testFiltersDifferentRepetitiveWords() async {
        // Given: A processor with default settings
        let mockProcessor = MockSpeechProcessor()
        let artifactFilter = ArtifactFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing text with "yes" repeated many times
        await artifactFilter.process(
            text: "yes, yes, yes, yes, yes, yes, yes",
            isFinal: true,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "fr-CA",
            source: "remote"
        )

        // Then: Text should be filtered out
        #expect(mockProcessor.processCount == 0)
    }

    @Test("Handles custom repetition threshold")
    @available(macOS 26.0, *)
    func testCustomRepetitionThreshold() async {
        // Given: A processor with a lower repetition threshold (2)
        let mockProcessor = MockSpeechProcessor()
        let artifactFilter = ArtifactFilterProcessor(nextProcessor: mockProcessor, repetitionThreshold: 2)

        // When: Processing text with 2 repetitions
        await artifactFilter.process(
            text: "no, no",
            isFinal: true,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should be filtered out (meets the threshold of 2)
        #expect(mockProcessor.processCount == 0)
    }

    @Test("Passes text with different words separated by commas")
    @available(macOS 26.0, *)
    func testPassesDifferentWords() async {
        // Given: A processor with default settings
        let mockProcessor = MockSpeechProcessor()
        let artifactFilter = ArtifactFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing text with different words
        let validText = "hello, world, how, are, you, today"
        await artifactFilter.process(
            text: validText,
            isFinal: true,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should pass through
        #expect(mockProcessor.processCount == 1)
        #expect(mockProcessor.processedTexts.first == validText)
    }

    @Test("Handles case-insensitive repetition detection")
    @available(macOS 26.0, *)
    func testCaseInsensitiveRepetition() async {
        // Given: A processor with default settings
        let mockProcessor = MockSpeechProcessor()
        let artifactFilter = ArtifactFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing text with case variations of the same word
        await artifactFilter.process(
            text: "No, no, NO, No, no, NO, no",
            isFinal: true,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should be filtered out (case-insensitive matching)
        #expect(mockProcessor.processCount == 0)
    }
}
