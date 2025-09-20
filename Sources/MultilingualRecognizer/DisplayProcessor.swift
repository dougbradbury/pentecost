import Foundation

@available(macOS 26.0, *)
final class DisplayProcessor: SpeechProcessor {

    private func flagForLocale(_ locale: String) -> String {
        switch locale {
        case "en-US", "en": return "🇺🇸"
        case "fr-FR", "fr": return "🇫🇷"
        default: return "🌍"
        }
    }

    func process(text: String, isFinal: Bool, startTime: Double, duration: Double, alternativeCount: Int, locale: String) async {
        let flag = flagForLocale(locale)
        if isFinal {
            print("\r\u{001B}[2K✅ \(flag) FINAL: \(text) [\(String(format: "%.1f", startTime))s-\(String(format: "%.1f", startTime + duration))s, \(alternativeCount) alt]")
        } else {
            print("\r⏳ \(flag) PARTIAL: \(text) [\(String(format: "%.1f", startTime))s]", terminator: "")
        }
        fflush(stdout)
    }
}