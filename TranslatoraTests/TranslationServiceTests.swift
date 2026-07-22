import Foundation
import Testing
@testable import Translatora

@MainActor
struct TranslationServiceTests {
    @Test
    func parsesStructuredResponseAndExamples() async throws {
        let completer = StubCompleter(
            content: """
            ```json
            {"translation":"你好，世界！","examples":[{"source":"Hello, friend!","translation":"你好，朋友！"}]}
            ```
            """
        )
        let service = TranslationService(modelProvider: completer)

        let result = try await service.translate(
            "Hello, world!",
            from: .english,
            to: .simplifiedChinese
        )

        #expect(result.translation == "你好，世界！")
        #expect(result.examples.count == 1)
        #expect(result.examples.first?.source == "Hello, friend!")
        #expect(completer.requests.count == 1)
        #expect(completer.requests.first?.messages.last?.content == "Hello, world!")
    }

    @Test
    func fallsBackToPlainTextResponse() async throws {
        let service = TranslationService(
            modelProvider: StubCompleter(content: "  一段普通译文  ")
        )

        let result = try await service.translate(
            "A plain sentence",
            from: .english,
            to: .simplifiedChinese
        )

        #expect(result.translation == "一段普通译文")
        #expect(result.examples.isEmpty)
    }
}

@MainActor
private final class StubCompleter: LLMCompleting {
    let content: String
    private(set) var requests: [LLMRequest] = []

    init(content: String) {
        self.content = content
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        requests.append(request)
        return LLMResponse(content: content, model: "stub")
    }
}
