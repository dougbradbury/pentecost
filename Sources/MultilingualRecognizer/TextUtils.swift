import Foundation

/// Utility functions for text processing and formatting
struct TextUtils {


    /// Formats text to fit exactly within a column width, padding with spaces
    /// - Parameters:
    ///   - text: The text to format
    ///   - width: The target column width
    /// - Returns: Text padded to exact width
    static func formatColumn(_ text: String, width: Int) -> String {
        return text.padding(toLength: width, withPad: " ", startingAt: 0)
    }

    /// Wraps text to fit within a specified width using the classic kata approach
    /// - Parameters:
    ///   - text: The text to wrap
    ///   - width: Maximum width per line
    /// - Returns: Array of lines, each within the specified width
    static func wrapText(_ text: String, width: Int) -> [String] {
        return wrap(text, width)
    }

    private static func wrap(_ text: String, _ column: Int) -> [String] {
        // Handle edge cases
        guard column > 0 else { return [text] }

        // Normalize whitespace
        let normalizedText = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        if normalizedText.isEmpty {
            return [""]
        }

        if normalizedText.count <= column {
            return [normalizedText]
        }

        let breakPoint = findBreakPoint(normalizedText, column)
        let firstLine = String(normalizedText.prefix(breakPoint))
        let remainder = String(normalizedText.dropFirst(breakPoint + 1))

        return [firstLine] + wrap(remainder, column)
    }

    private static func findBreakPoint(_ text: String, _ column: Int) -> Int {
        let prefix = text.prefix(column)
        let lastSpace = prefix.lastIndex(of: " ")

        if let spaceIndex = lastSpace {
            return text.distance(from: text.startIndex, to: spaceIndex)
        } else {
            return column
        }
    }
}

extension String {
    func chunked(into size: Int) -> [String] {
        return stride(from: 0, to: self.count, by: size).map {
            let start = self.index(self.startIndex, offsetBy: $0)
            let end = self.index(start, offsetBy: min(size, self.count - $0))
            return String(self[start..<end])
        }
    }
}