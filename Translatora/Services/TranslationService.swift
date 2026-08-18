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
                    content: "Explain and translate this screenshot as one cohesive paragraph according to the instructions.",
                    imageDataURL: imageDataURL
                )
            ],
            temperature: 0.1,
            maxTokens: 1_600
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
        You are a screenshot understanding and translation assistant. Analyze the attached screenshot and answer in \(targetLanguage.promptName).

        Write exactly one cohesive paragraph, usually 3-6 concise sentences. Explain what the screenshot is, its main purpose, and its key message. Naturally incorporate the meaning and translation of the important visible text into that explanation. Quote a short original phrase only when it helps the reader connect the translation to the screenshot.

        Do not enumerate or explain text elements one by one. Do not produce headings, lists, bullets, numbering, tables, JSON, XML, Markdown, or code fences. Do not exhaustively transcribe minor labels, repeated text, or interface chrome. Mention layout or location only when it is necessary to understand the content. If text is already in \(targetLanguage.promptName), explain its meaning naturally instead of mechanically repeating it. Never invent unreadable text.

        If the screenshot contains no readable text, describe its visual content and likely purpose in the same single-paragraph format. Return plain text only.
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
        let explanation = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
        return TranslationResult(
            translation: explanation,
            examples: []
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
