import Foundation

struct TranscriptionMessage: Identifiable {
    let id: UUID
    let timestamp: Date
    let text: String
    let translation: String?
    let isEnglish: Bool
    let isLocal: Bool // true for local/microphone, false for remote/system

    init(id: UUID = UUID(), timestamp: Date = Date(), text: String, translation: String? = nil, isEnglish: Bool, isLocal: Bool) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.translation = translation
        self.isEnglish = isEnglish
        self.isLocal = isLocal
    }
}

enum TranslationLanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case french = "Français"
    case none = "No Translation"
    
    var id: String { rawValue }
    
    var localeIdentifier: String {
        switch self {
        case .english: return "en"
        case .french: return "fr"
        case .none: return ""
        }
    }
    
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .french: return "🇫🇷"
        case .none: return "🚫"
        }
    }
}

struct AppSettings {
    var localTranslationLanguage: TranslationLanguage = .french
    var remoteTranslationLanguage: TranslationLanguage = .english
}
