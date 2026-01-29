import Foundation
import Testing
@testable import MultilingualRecognizer

@Suite("MinimumLengthFilterProcessor Tests")
struct MinimumLengthFilterProcessorTests {

    @Test("Always passes final results regardless of length")
    @available(macOS 26.0, *)
    func testPassesFinalResults() async {
        // Given: A processor with default settings
        let mockProcessor = MockSpeechProcessor()
        let lengthFilter = MinimumLengthFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing a short final result
        let shortText = "Hi"
        await lengthFilter.process(
            text: shortText,
            isFinal: true,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should pass through even though it's short
        #expect(mockProcessor.processCount == 1)
        #expect(mockProcessor.processedTexts.first == shortText)
    }

    @Test("Filters short partial results")
    @available(macOS 26.0, *)
    func testFiltersShortPartialResults() async {
        // Given: A processor with default settings (5 words minimum)
        let mockProcessor = MockSpeechProcessor()
        let lengthFilter = MinimumLengthFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing a short partial result (3 words)
        await lengthFilter.process(
            text: "This is short",
            isFinal: false,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should be filtered out
        #expect(mockProcessor.processCount == 0)
    }

    @Test("Passes long partial results")
    @available(macOS 26.0, *)
    func testPassesLongPartialResults() async {
        // Given: A processor with default settings (5 words minimum)
        let mockProcessor = MockSpeechProcessor()
        let lengthFilter = MinimumLengthFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing a long partial result (6 words)
        let longText = "This is a longer partial result"
        await lengthFilter.process(
            text: longText,
            isFinal: false,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should pass through
        #expect(mockProcessor.processCount == 1)
        #expect(mockProcessor.processedTexts.first == longText)
    }

    @Test("Passes partial results with exactly minimum word count")
    @available(macOS 26.0, *)
    func testPassesExactMinimumWordCount() async {
        // Given: A processor with default settings (5 words minimum)
        let mockProcessor = MockSpeechProcessor()
        let lengthFilter = MinimumLengthFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing a partial result with exactly 5 words
        let exactText = "This has exactly five words"
        await lengthFilter.process(
            text: exactText,
            isFinal: false,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should pass through
        #expect(mockProcessor.processCount == 1)
        #expect(mockProcessor.processedTexts.first == exactText)
    }

    @Test("Handles custom minimum word count")
    @available(macOS 26.0, *)
    func testCustomMinimumWordCount() async {
        // Given: A processor with custom minimum (3 words)
        let mockProcessor = MockSpeechProcessor()
        let lengthFilter = MinimumLengthFilterProcessor(nextProcessor: mockProcessor, minimumWordCount: 3)

        // When: Processing a partial result with 3 words
        let threeWords = "Just three words"
        await lengthFilter.process(
            text: threeWords,
            isFinal: false,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should pass through
        #expect(mockProcessor.processCount == 1)
        #expect(mockProcessor.processedTexts.first == threeWords)
    }

    @Test("Handles text with multiple spaces")
    @available(macOS 26.0, *)
    func testHandlesMultipleSpaces() async {
        // Given: A processor with default settings
        let mockProcessor = MockSpeechProcessor()
        let lengthFilter = MinimumLengthFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing text with multiple spaces (still 5 words)
        let spacedText = "This   has   exactly    five   words"
        await lengthFilter.process(
            text: spacedText,
            isFinal: false,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should pass through (counts as 5 words)
        #expect(mockProcessor.processCount == 1)
    }

    @Test("Filters empty partial results")
    @available(macOS 26.0, *)
    func testFiltersEmptyPartialResults() async {
        // Given: A processor with default settings
        let mockProcessor = MockSpeechProcessor()
        let lengthFilter = MinimumLengthFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing empty partial result
        await lengthFilter.process(
            text: "   ",
            isFinal: false,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should be filtered out
        #expect(mockProcessor.processCount == 0)
    }

    @Test("Passes empty final results")
    @available(macOS 26.0, *)
    func testPassesEmptyFinalResults() async {
        // Given: A processor with default settings
        let mockProcessor = MockSpeechProcessor()
        let lengthFilter = MinimumLengthFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing empty final result
        await lengthFilter.process(
            text: "   ",
            isFinal: true,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Final results always pass through
        #expect(mockProcessor.processCount == 1)
    }

    @Test("Filters single word partial results")
    @available(macOS 26.0, *)
    func testFiltersSingleWord() async {
        // Given: A processor with default settings (5 words minimum)
        let mockProcessor = MockSpeechProcessor()
        let lengthFilter = MinimumLengthFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing a single word partial result
        await lengthFilter.process(
            text: "Hello",
            isFinal: false,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "en-US",
            source: "local"
        )

        // Then: Text should be filtered out
        #expect(mockProcessor.processCount == 0)
    }

    @Test("Works with French text")
    @available(macOS 26.0, *)
    func testWorksWithFrenchText() async {
        // Given: A processor with default settings
        let mockProcessor = MockSpeechProcessor()
        let lengthFilter = MinimumLengthFilterProcessor(nextProcessor: mockProcessor)

        // When: Processing French text with 6 words
        let frenchText = "Ceci est un test de longueur"
        await lengthFilter.process(
            text: frenchText,
            isFinal: false,
            startTime: 0.0,
            duration: 1.0,
            alternativeCount: 1,
            locale: "fr-CA",
            source: "remote"
        )

        // Then: Text should pass through
        #expect(mockProcessor.processCount == 1)
        #expect(mockProcessor.processedTexts.first == frenchText)
    }
}
