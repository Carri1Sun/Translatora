import Foundation

enum TranslationLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case english
    case simplifiedChinese
    case traditionalChinese
    case japanese
    case korean
    case french
    case german
    case spanish

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "英语"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁体中文"
        case .japanese: "日语"
        case .korean: "韩语"
        case .french: "法语"
        case .german: "德语"
        case .spanish: "西班牙语"
        }
    }

    var promptName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "Simplified Chinese"
        case .traditionalChinese: "Traditional Chinese"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .french: "French"
        case .german: "German"
        case .spanish: "Spanish"
        }
    }
}

struct TranslationExample: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var source: String
    var translation: String

    init(id: UUID = UUID(), source: String, translation: String) {
        self.id = id
        self.source = source
        self.translation = translation
    }
}

struct TranslationResult: Equatable, Sendable {
    var translation: String
    var examples: [TranslationExample]
}

struct DictionaryEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var sourceText: String
    var translatedText: String
    var note: String
    var sourceLanguage: TranslationLanguage
    var targetLanguage: TranslationLanguage
    var examples: [TranslationExample]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        note: String = "",
        sourceLanguage: TranslationLanguage,
        targetLanguage: TranslationLanguage,
        examples: [TranslationExample] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.note = note
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.examples = examples
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
