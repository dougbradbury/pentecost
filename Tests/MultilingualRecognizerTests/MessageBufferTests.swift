import XCTest
@testable import MultilingualRecognizer

@available(macOS 26.0, *)
final class MessageBufferTests: XCTestCase {

    var messageBuffer: MessageBuffer!

    override func setUp() {
        super.setUp()
        messageBuffer = MessageBuffer()
    }

    override func tearDown() {
        messageBuffer = nil
        super.tearDown()
    }

    // MARK: - Basic Message Addition Tests

    func testAddSingleMessage() async {
        await messageBuffer.updateMessage(text: "Hello world", isFinal: false, startTime: 1.0, duration: 0.5, locale: "en-US")

        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].text, "Hello world")
        XCTAssertEqual(messages[0].isFinal, false)
        XCTAssertEqual(messages[0].startTime, 1.0, accuracy: 0.001)
        XCTAssertEqual(messages[0].duration, 0.5, accuracy: 0.001)
        XCTAssertEqual(messages[0].locale, "en-US")
    }

    func testAddMultipleMessages() async {
        await messageBuffer.updateMessage(text: "First", isFinal: true, startTime: 1.0, duration: 0.5, locale: "en-US")
        await messageBuffer.updateMessage(text: "Second", isFinal: false, startTime: 2.0, duration: 0.3, locale: "fr-FR")
        await messageBuffer.updateMessage(text: "Third", isFinal: true, startTime: 3.0, duration: 0.7, locale: "es-ES")

        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[0].text, "First")
        XCTAssertEqual(messages[1].text, "Second")
        XCTAssertEqual(messages[2].text, "Third")
    }

    func testInitiallyEmpty() async {
        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 0)
    }

    // MARK: - Message Update Tests

    func testUpdateExistingMessage() async {
        // Add initial message
        await messageBuffer.updateMessage(text: "Hello", isFinal: false, startTime: 1.0, duration: 0.5, locale: "en-US")

        // Update the same message (same startTime within tolerance)
        await messageBuffer.updateMessage(text: "Hello world", isFinal: true, startTime: 1.05, duration: 0.8, locale: "en-US")

        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 1) // Should still be one message
        XCTAssertEqual(messages[0].text, "Hello world") // Text updated
        XCTAssertEqual(messages[0].isFinal, true) // Status updated
        XCTAssertEqual(messages[0].duration, 0.8, accuracy: 0.001) // Duration updated
        XCTAssertEqual(messages[0].startTime, 1.0, accuracy: 0.001) // StartTime remains original
    }

    func testUpdateWithinTimeTolerance() async {
        await messageBuffer.updateMessage(text: "Original", isFinal: false, startTime: 1.0, duration: 0.5, locale: "en-US")

        // Update with startTime within 0.1 tolerance (1.09 is within 0.1 of 1.0)
        await messageBuffer.updateMessage(text: "Updated", isFinal: true, startTime: 1.09, duration: 0.8, locale: "en-US")

        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].text, "Updated")
    }

    func testUpdateOutsideTimeTolerance() async {
        await messageBuffer.updateMessage(text: "First", isFinal: false, startTime: 1.0, duration: 0.5, locale: "en-US")

        // Add with startTime outside 0.1 tolerance and after First ends (1.6 is after 1.5)
        await messageBuffer.updateMessage(text: "Second", isFinal: true, startTime: 1.6, duration: 0.8, locale: "en-US")

        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 2) // Should be two separate messages
        XCTAssertEqual(messages[0].text, "First")
        XCTAssertEqual(messages[1].text, "Second")
    }

    // MARK: - Chronological Ordering Tests

    func testMessagesAreOrderedByStartTime() async {
        // Add messages out of chronological order
        await messageBuffer.updateMessage(text: "Third", isFinal: true, startTime: 3.0, duration: 0.5, locale: "en-US")
        await messageBuffer.updateMessage(text: "First", isFinal: true, startTime: 1.0, duration: 0.5, locale: "en-US")
        await messageBuffer.updateMessage(text: "Second", isFinal: true, startTime: 2.0, duration: 0.5, locale: "en-US")

        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[0].text, "First")
        XCTAssertEqual(messages[0].startTime, 1.0, accuracy: 0.001)
        XCTAssertEqual(messages[1].text, "Second")
        XCTAssertEqual(messages[1].startTime, 2.0, accuracy: 0.001)
        XCTAssertEqual(messages[2].text, "Third")
        XCTAssertEqual(messages[2].startTime, 3.0, accuracy: 0.001)
    }

    func testOrderingMaintainedAfterUpdates() async {
        // Add messages in order
        await messageBuffer.updateMessage(text: "First", isFinal: false, startTime: 1.0, duration: 0.5, locale: "en-US")
        await messageBuffer.updateMessage(text: "Second", isFinal: false, startTime: 2.0, duration: 0.5, locale: "en-US")
        await messageBuffer.updateMessage(text: "Third", isFinal: false, startTime: 3.0, duration: 0.5, locale: "en-US")

        // Update middle message
        await messageBuffer.updateMessage(text: "Second Updated", isFinal: true, startTime: 2.0, duration: 0.8, locale: "en-US")

        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[0].text, "First")
        XCTAssertEqual(messages[1].text, "Second Updated") // Updated but still in correct position
        XCTAssertEqual(messages[2].text, "Third")
    }

    // MARK: - EndTime Calculation Tests

    func testEndTimeCalculation() async {
        await messageBuffer.updateMessage(text: "Test", isFinal: true, startTime: 1.5, duration: 2.3, locale: "en-US")

        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 1)

        let expectedEndTime = 1.5 + 2.3 // 3.8
        XCTAssertEqual(messages[0].endTime, expectedEndTime, accuracy: 0.001)
    }

    func testEndTimeAfterUpdate() async {
        await messageBuffer.updateMessage(text: "Test", isFinal: false, startTime: 1.0, duration: 1.0, locale: "en-US")
        await messageBuffer.updateMessage(text: "Test Updated", isFinal: true, startTime: 1.0, duration: 2.5, locale: "en-US")

        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 1)

        let expectedEndTime = 1.0 + 2.5 // 3.5
        XCTAssertEqual(messages[0].endTime, expectedEndTime, accuracy: 0.001)
    }

    // MARK: - Clear Messages Tests

    func testClearMessages() async {
        await messageBuffer.updateMessage(text: "First", isFinal: true, startTime: 1.0, duration: 0.5, locale: "en-US")
        await messageBuffer.updateMessage(text: "Second", isFinal: true, startTime: 2.0, duration: 0.5, locale: "en-US")

        let count1 = await messageBuffer.getMessages().count
        XCTAssertEqual(count1, 2)

        await messageBuffer.clearMessages()
        let count2 = await messageBuffer.getMessages().count
        XCTAssertEqual(count2, 0)
    }

    func testClearEmptyBuffer() async {
        let count1 = await messageBuffer.getMessages().count
        XCTAssertEqual(count1, 0)

        await messageBuffer.clearMessages() // Should not crash
        let count2 = await messageBuffer.getMessages().count
        XCTAssertEqual(count2, 0)
    }

    // MARK: - Language Agnostic Tests

    func testLanguageAgnostic() async {
        // Should work with any locale string
        await messageBuffer.updateMessage(text: "English", isFinal: true, startTime: 1.0, duration: 0.5, locale: "en-US")
        await messageBuffer.updateMessage(text: "French", isFinal: true, startTime: 2.0, duration: 0.5, locale: "fr-FR")
        await messageBuffer.updateMessage(text: "Spanish", isFinal: true, startTime: 3.0, duration: 0.5, locale: "es-ES")
        await messageBuffer.updateMessage(text: "Chinese", isFinal: true, startTime: 4.0, duration: 0.5, locale: "zh-CN")
        await messageBuffer.updateMessage(text: "Custom", isFinal: true, startTime: 5.0, duration: 0.5, locale: "custom-locale")

        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 5)
        XCTAssertEqual(messages[0].locale, "en-US")
        XCTAssertEqual(messages[1].locale, "fr-FR")
        XCTAssertEqual(messages[2].locale, "es-ES")
        XCTAssertEqual(messages[3].locale, "zh-CN")
        XCTAssertEqual(messages[4].locale, "custom-locale")
    }

    // MARK: - Edge Cases

    func testZeroDuration() async {
        await messageBuffer.updateMessage(text: "Test", isFinal: true, startTime: 1.0, duration: 0.0, locale: "en-US")

        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].endTime, 1.0, accuracy: 0.001)
    }

    func testNegativeDuration() async {
        await messageBuffer.updateMessage(text: "Test", isFinal: true, startTime: 1.0, duration: -0.5, locale: "en-US")

        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].endTime, 0.5, accuracy: 0.001) // 1.0 + (-0.5)
    }

    func testZeroStartTime() async {
        await messageBuffer.updateMessage(text: "Test", isFinal: true, startTime: 0.0, duration: 1.0, locale: "en-US")

        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].startTime, 0.0, accuracy: 0.001)
        XCTAssertEqual(messages[0].endTime, 1.0, accuracy: 0.001)
    }

    func testEmptyText() async {
        await messageBuffer.updateMessage(text: "", isFinal: true, startTime: 1.0, duration: 0.5, locale: "en-US")

        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].text, "")
    }

    func testEmptyLocale() async {
        await messageBuffer.updateMessage(text: "Test", isFinal: true, startTime: 1.0, duration: 0.5, locale: "")

        let messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].locale, "")
    }

    // MARK: - Realistic Speech Recognition Scenarios

    func testOldPendingMessageReplacementScenario() async {
        // Scenario: After silence, analyzer first detects something far back in time as pending,
        // then corrects with actual speech start time

        // Step 1: Current time is around 10 seconds, someone starts talking
        await messageBuffer.updateMessage(text: "Hello", isFinal: false, startTime: 10.0, duration: 0.5, locale: "en-US")

        // Step 2: Analyzer initially reports some phantom detection from way back during silence
        // This is a pending message with start time much earlier
        await messageBuffer.updateMessage(text: "Hmm", isFinal: false, startTime: 5.0, duration: 1.0, locale: "en-US")

        // At this point we should have 2 messages (they're outside 0.1s tolerance)
        var messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].startTime, 5.0, accuracy: 0.001) // Chronologically first
        XCTAssertEqual(messages[0].text, "Hmm")
        XCTAssertEqual(messages[1].startTime, 10.0, accuracy: 0.001)
        XCTAssertEqual(messages[1].text, "Hello")

        // Step 3: Update comes in that corrects the phantom detection - same text but proper start time
        // This should replace the old pending "Hmm" message even though start time is very different
        // Use a start time that doesn't overlap with "Hello" (which ends at 10.5)
        await messageBuffer.updateMessage(text: "Hmm", isFinal: false, startTime: 11.0, duration: 0.8, locale: "en-US")

        // Now we should still have 2 messages, but the "Hmm" should be updated to the correct time
        messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 2)

        // The messages should now be in the correct order
        XCTAssertEqual(messages[0].startTime, 10.0, accuracy: 0.001) // "Hello"
        XCTAssertEqual(messages[0].text, "Hello")
        XCTAssertEqual(messages[1].startTime, 11.0, accuracy: 0.001) // "Hmm" updated to correct time
        XCTAssertEqual(messages[1].text, "Hmm")
        XCTAssertEqual(messages[1].duration, 0.8, accuracy: 0.001) // Duration updated too
    }

    func testPendingMessageTextMatchingWithTimeCorrection() async {
        // Similar scenario but focusing on text matching for pending messages

        // Add some established final messages
        await messageBuffer.updateMessage(text: "Previous", isFinal: true, startTime: 8.0, duration: 1.0, locale: "en-US")

        // Phantom detection from way back
        await messageBuffer.updateMessage(text: "Let me jump in", isFinal: false, startTime: 2.0, duration: 8.5, locale: "en-US")

        // Current actual speech
        await messageBuffer.updateMessage(text: "Let me jump in and tell you", isFinal: false, startTime: 10.0, duration: 6.5, locale: "en-US")

        // Should have 3 messages at this point
        var messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 2)

        // Correction comes in: same text "Testing" but with proper timing near current speech
        await messageBuffer.updateMessage(text: "Let me jump in and tell you something", isFinal: true, startTime: 10.5, duration: 7.7, locale: "en-US")

        // Should still have 3 messages, but "Testing" moved to correct position
        messages = await messageBuffer.getMessages()
        XCTAssertEqual(messages.count, 2)

        // Verify chronological order and that "Testing" was moved
        XCTAssertEqual(messages[0].text, "Previous")
        XCTAssertEqual(messages[0].startTime, 8.0, accuracy: 0.001)

        XCTAssertEqual(messages[1].text, "Let me jump in and tell you something")
        XCTAssertEqual(messages[1].startTime, 10.5, accuracy: 0.001)
    }
}
