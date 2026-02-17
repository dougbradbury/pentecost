import Foundation
import Darwin

@available(macOS 26.0, *)
final class TerminalRenderer: @unchecked Sendable {
    private let leftMargin = 0

    // Store previous rendered state for differential updates
    private var previousLines: [String] = []
    private var previousTerminalSize: (width: Int, height: Int) = (0, 0)
    private var isFirstRender = true

    // Render throttling to prevent excessive updates
    private var lastRenderTime: Date = Date.distantPast
    private let renderThrottleInterval: TimeInterval = 0.05 // 50ms minimum between renders (20 FPS max)

    // Dynamically calculate terminal width
    private var terminalWidth: Int {
        return getTerminalWidth()
    }

    // Dynamically calculate column width based on current terminal width
    private var columnWidth: Int {
        let width = (terminalWidth - 4) / 2  // -4 for separator and margins
        return max(20, width)  // Ensure minimum width of 20
    }

    private var rightMargin: Int { leftMargin + columnWidth + 2 } // +2 for separator

    init() {
        // No longer need fixed width parameter
    }

    // Dynamically calculate max display lines based on terminal height
    private var maxDisplayLines: Int {
        let terminalHeight = getTerminalHeight()
        // Reserve 3 lines for header, separator, and bottom margin
        return max(5, terminalHeight - 3)
    }

    private func getTerminalHeight() -> Int {
        var winsize = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &winsize) == 0 {
            return Int(winsize.ws_row)
        }
        return 25 // fallback if detection fails
    }

    private func getTerminalWidth() -> Int {
        var winsize = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &winsize) == 0 {
            let width = Int(winsize.ws_col)
            return width > 0 ? width : 120  // Ensure positive value
        }
        return 120 // fallback if detection fails
    }

    func render(englishMessages: [SpeechMessage], frenchMessages: [SpeechMessage]) {
        let now = Date()
        let timeSinceLastRender = now.timeIntervalSince(lastRenderTime)

        // Throttle rendering to prevent excessive updates
        if !isFirstRender && timeSinceLastRender < renderThrottleInterval {
            return
        }

        let currentTerminalSize = (width: terminalWidth, height: getTerminalHeight())

        // Check if terminal size changed - if so, do full redraw
        let terminalResized = currentTerminalSize != previousTerminalSize

        // Build new frame content
        var newLines: [String] = []

        // Add header
        let header = createHeader()
        newLines.append(header)
        newLines.append(String(repeating: "─", count: terminalWidth))

        // Get wrapped lines for both columns with proper formatting
        let wrappedEnglish = englishMessages.flatMap { $0.formatForColumn(width: columnWidth) }
        let wrappedFrench = frenchMessages.flatMap { $0.formatForColumn(width: columnWidth) }

        // Build content lines
        let maxLines = max(wrappedEnglish.count, wrappedFrench.count)
        let displayLines = min(maxLines, maxDisplayLines)

        // Calculate offset to show the most recent lines
        let englishOffset = max(0, wrappedEnglish.count - displayLines)
        let frenchOffset = max(0, wrappedFrench.count - displayLines)

        for i in 0..<displayLines {
            let englishIndex = englishOffset + i
            let frenchIndex = frenchOffset + i

            let englishLine = englishIndex < wrappedEnglish.count ? wrappedEnglish[englishIndex] : ""
            let frenchLine = frenchIndex < wrappedFrench.count ? wrappedFrench[frenchIndex] : ""

            // Pad each line to exact column width, accounting for emoji visual width
            let leftColumn = formatColumnText(englishLine, width: columnWidth)
            let rightColumn = formatColumnText(frenchLine, width: columnWidth)

            newLines.append("\(leftColumn) │ \(rightColumn)")
        }

        // Perform differential rendering
        if isFirstRender || terminalResized {
            // Full redraw on first render or terminal resize
            print("\u{001B}[2J\u{001B}[H", terminator: "")
            for line in newLines {
                print(line)
            }
            isFirstRender = false
        } else {
            // Differential update - only change lines that differ
            performDifferentialUpdate(newLines: newLines)
        }

        // Store current state for next comparison
        previousLines = newLines
        previousTerminalSize = currentTerminalSize
        lastRenderTime = now

        fflush(stdout)
    }

    // Force immediate render bypassing throttle (useful for critical updates)
    func forceRender(englishMessages: [SpeechMessage], frenchMessages: [SpeechMessage]) {
        lastRenderTime = Date.distantPast // Reset throttle
        render(englishMessages: englishMessages, frenchMessages: frenchMessages)
    }

    // Full screen clear then render - use when clearing the transcript
    func clearAndRender(englishMessages: [SpeechMessage], frenchMessages: [SpeechMessage]) {
        lastRenderTime = Date.distantPast
        isFirstRender = true  // Force full redraw instead of differential update
        render(englishMessages: englishMessages, frenchMessages: frenchMessages)
    }

    private func performDifferentialUpdate(newLines: [String]) {
        let maxLines = max(newLines.count, previousLines.count)

        for lineIndex in 0..<maxLines {
            let newLine = lineIndex < newLines.count ? newLines[lineIndex] : ""
            let oldLine = lineIndex < previousLines.count ? previousLines[lineIndex] : ""

            // Only update if line has changed
            if newLine != oldLine {
                // Move cursor to specific line (1-indexed)
                print("\u{001B}[\(lineIndex + 1);1H", terminator: "")

                // Clear the entire line and write new content
                print("\u{001B}[2K\(newLine)", terminator: "")
            }
        }

        // If new content has fewer lines than before, clear remaining lines
        if newLines.count < previousLines.count {
            for lineIndex in newLines.count..<previousLines.count {
                print("\u{001B}[\(lineIndex + 1);1H", terminator: "")
                print("\u{001B}[2K", terminator: "") // Clear entire line
            }
        }
    }

    private func createHeader() -> String {
        let englishHeader = "ENGLISH".padding(toLength: columnWidth, withPad: " ", startingAt: 0)
        let frenchHeader = "FRENCH".padding(toLength: columnWidth, withPad: " ", startingAt: 0)
        return "\(englishHeader) │ \(frenchHeader)"
    }

    private func formatColumnText(_ text: String, width: Int) -> String {
        return TextUtils.formatColumn(text, width: width)
    }
}
