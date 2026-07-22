import Foundation

@MainActor
final class TranslationService {
    private let modelProvider: any LLMCompleting

    init(modelProvider: any LLMCompleting) {
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
