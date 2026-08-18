import Foundation

@MainActor
final class TranslationService {
    private let modelProvider: any LanguageModelCompleting

    init(modelProvider: any LanguageModelCompleting) {
        self.modelProvider = modelProvider
    }

    func translate(
        _ text: String,
        from sourceLanguage: TranslationLanguage,
        to targetLanguage: TranslationLanguage
    ) async throws -> TranslationResult {
        let request = LLMRequest(
            messages: [
                LLMMessage(
                    role: .system,
                    content: systemPrompt(
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage
                    )
                ),
                LLMMessage(role: .user, content: text)
            ],
            temperature: 0.2,
            maxTokens: 1_200
        )

        let response = try await modelProvider.complete(request)
        return parse(response.content)
    }

    func translateScreenshot(
        imageData: Data,
        to targetLanguage: TranslationLanguage
    ) async throws -> TranslationResult {
        guard modelProvider.supportsImageInput else {
            throw LLMProviderError.imageInputUnsupported("当前所选模型")
        }

        let imageDataURL = "data:image/png;base64,\(imageData.base64EncodedString())"
        let request = LLMRequest(
            messages: [
                LLMMessage(
                    role: .system,
                    content: screenshotSystemPrompt(targetLanguage: targetLanguage)
                ),
                LLMMessage(
                    role: .user,
                    content: "Analyze every meaningful text element in this screenshot and translate it according to the instructions.",
                    imageDataURL: imageDataURL
                )
            ],
            temperature: 0.1,
            maxTokens: 4_000
        )

        let response = try await modelProvider.complete(request)
        return parseScreenshot(response.content)
    }

    private func systemPrompt(
        sourceLanguage: TranslationLanguage,
        targetLanguage: TranslationLanguage
    ) -> String {
        """
        You are a precise translation assistant. Translate the user's text from \(sourceLanguage.promptName) to \(targetLanguage.promptName).
        Preserve tone, meaning, formatting, names, and technical terminology.
        Return only one valid JSON object with this exact shape:
        {"translation":"translated text","examples":[{"source":"a natural example in \(sourceLanguage.promptName)","translation":"the matching example in \(targetLanguage.promptName)"}]}
        Include 1 or 2 concise examples that demonstrate the translated word or phrase in context. If examples would not help for a long passage, return an empty examples array. Do not use Markdown fences.
        """
    }

    private func screenshotSystemPrompt(targetLanguage: TranslationLanguage) -> String {
        """
        You are a precise screenshot understanding and translation assistant. Analyze the attached screenshot and write all output in \(targetLanguage.promptName), except that sourceText must preserve the visible original text exactly.

        Work in natural visual reading order, generally top-to-bottom and left-to-right. Include every meaningful visible text element: titles, headings, body text, bullets, table cells, chart labels, buttons, menus, captions, annotations, and status text. Keep separate elements separate when they serve different roles. Ignore purely decorative shapes and do not invent text that is unreadable.

        For each element:
        - sourceText: copy the visible text exactly, preserving important punctuation and line breaks.
        - translatedText: translate naturally into \(targetLanguage.promptName). If it is already in \(targetLanguage.promptName), briefly restate its meaning instead of repeating it mechanically.
        - context: briefly explain where the element appears and what it does or represents, in \(targetLanguage.promptName).

        The summary must be a concise 1-3 sentence explanation of the screenshot's overall purpose and main message in \(targetLanguage.promptName).

        Return only one valid JSON object with this exact shape:
        {"summary":"concise overall summary","elements":[{"sourceText":"visible original text","translatedText":"translation","context":"location and role"}]}
        Do not use Markdown fences. If no readable text exists, return an empty elements array and explain the visual content briefly in summary.
        """
    }

    private func parse(_ content: String) -> TranslationResult {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if let payload = decodePayload(from: trimmed) {
            let examples = payload.examples.prefix(2).map {
                TranslationExample(source: $0.source, translation: $0.translation)
            }
            return TranslationResult(
                translation: payload.translation.trimmingCharacters(in: .whitespacesAndNewlines),
                examples: Array(examples)
            )
        }

        return TranslationResult(translation: trimmed, examples: [])
    }

    private func parseScreenshot(_ content: String) -> TranslationResult {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = jsonData(from: trimmed),
              let payload = try? JSONDecoder().decode(ScreenshotTranslationPayload.self, from: data) else {
            return TranslationResult(
                translation: trimmed,
                examples: [],
                screenshotTranslation: ScreenshotTranslation(summary: trimmed, elements: [])
            )
        }

        let summary = payload.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let elements = payload.elements.compactMap { element -> ScreenshotTranslationElement? in
            let sourceText = element.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            let translatedText = element.translatedText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !sourceText.isEmpty || !translatedText.isEmpty else { return nil }
            return ScreenshotTranslationElement(
                sourceText: sourceText,
                translatedText: translatedText,
                context: element.context.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        let screenshotTranslation = ScreenshotTranslation(summary: summary, elements: elements)
        return TranslationResult(
            translation: summary,
            examples: [],
            screenshotTranslation: screenshotTranslation
        )
    }

    private func decodePayload(from content: String) -> TranslationPayload? {
        if let data = content.data(using: .utf8),
           let payload = try? JSONDecoder().decode(TranslationPayload.self, from: data) {
            return payload
        }

        guard let openingBrace = content.firstIndex(of: "{"),
              let closingBrace = content.lastIndex(of: "}"),
              openingBrace <= closingBrace else {
            return nil
        }

        let json = String(content[openingBrace...closingBrace])
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TranslationPayload.self, from: data)
    }

    private func jsonData(from content: String) -> Data? {
        if let data = content.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        guard let openingBrace = content.firstIndex(of: "{"),
              let closingBrace = content.lastIndex(of: "}"),
              openingBrace <= closingBrace else {
            return nil
        }
        return String(content[openingBrace...closingBrace]).data(using: .utf8)
    }
}

private struct TranslationPayload: Decodable {
    struct Example: Decodable {
        let source: String
        let translation: String
    }

    let translation: String
    let examples: [Example]

    private enum CodingKeys: String, CodingKey {
        case translation
        case examples
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        translation = try container.decode(String.self, forKey: .translation)
        examples = try container.decodeIfPresent([Example].self, forKey: .examples) ?? []
    }
}

private struct ScreenshotTranslationPayload: Decodable {
    struct Element: Decodable {
        let sourceText: String
        let translatedText: String
        let context: String
    }

    let summary: String
    let elements: [Element]

    private enum CodingKeys: String, CodingKey {
        case summary
        case elements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        elements = try container.decodeIfPresent([Element].self, forKey: .elements) ?? []
    }
}
