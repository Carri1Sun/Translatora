import Foundation

enum TranslationLanguage: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
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

struct ScreenshotTranslationElement: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var sourceText: String
    var translatedText: String
    var context: String

    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        context: String
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.context = context
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        sourceText = try container.decode(String.self, forKey: .sourceText)
        translatedText = try container.decode(String.self, forKey: .translatedText)
        context = (try? container.decode(String.self, forKey: .context)) ?? ""
    }
}

struct TranslationResult: Equatable, Sendable {
    var translation: String
    var examples: [TranslationExample]

    init(
        translation: String,
        examples: [TranslationExample]
    ) {
        self.translation = translation
        self.examples = examples
    }
}

struct DictionaryEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var sourceText: String
    var translatedText: String
    var note: String
    var sourceLanguage: TranslationLanguage
    var targetLanguage: TranslationLanguage
    var examples: [TranslationExample]
    var sourceImageData: Data?
    var screenshotElements: [ScreenshotTranslationElement]
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
        sourceImageData: Data? = nil,
        screenshotElements: [ScreenshotTranslationElement] = [],
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
        self.sourceImageData = sourceImageData
        self.screenshotElements = screenshotElements
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceText = try container.decode(String.self, forKey: .sourceText)
        translatedText = try container.decode(String.self, forKey: .translatedText)
        sourceLanguage = try container.decode(
            TranslationLanguage.self,
            forKey: .sourceLanguage
        )
        targetLanguage = try container.decode(
            TranslationLanguage.self,
            forKey: .targetLanguage
        )
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        note = (try? container.decode(String.self, forKey: .note)) ?? ""
        examples = (try? container.decode(
            [TranslationExample].self,
            forKey: .examples
        )) ?? []
        sourceImageData = try? container.decodeIfPresent(Data.self, forKey: .sourceImageData)
        screenshotElements = (try? container.decode(
            [ScreenshotTranslationElement].self,
            forKey: .screenshotElements
        )) ?? []
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? .distantPast
        updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? createdAt
    }

    var isScreenshotTranslation: Bool {
        sourceImageData != nil
    }
}
