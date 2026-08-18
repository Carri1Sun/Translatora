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

    @Test
    func translatesScreenshotIntoSingleExplanationParagraph() async throws {
        let completer = StubCompleter(
            content: """
            这是一页产品发布幻灯片，主标题“Launch Day”表示“发布日”。

            副标题强调要有信心地发布产品，整体用于传达产品即将上线的信息。
            """,
            supportsImageInput: true
        )
        let service = TranslationService(modelProvider: completer)

        let result = try await service.translateScreenshot(
            imageData: Data([0x89, 0x50, 0x4e, 0x47]),
            to: .simplifiedChinese
        )

        #expect(
            result.translation
                == "这是一页产品发布幻灯片，主标题“Launch Day”表示“发布日”。 副标题强调要有信心地发布产品，整体用于传达产品即将上线的信息。"
        )
        #expect(result.examples.isEmpty)
        let request = try #require(completer.requests.first)
        #expect(request.messages.last?.imageDataURL?.hasPrefix("data:image/png;base64,") == true)
        #expect(request.messages.last?.content.contains("one cohesive paragraph") == true)
        #expect(request.messages.first?.content.contains("Simplified Chinese") == true)
        #expect(request.messages.first?.content.contains("Do not enumerate") == true)
        #expect(request.maxTokens == 1_600)
    }

    @Test
    func rejectsScreenshotForTextOnlyModel() async {
        let service = TranslationService(modelProvider: StubCompleter(content: "unused"))

        await #expect(
            throws: LLMProviderError.imageInputUnsupported("当前所选模型")
        ) {
            try await service.translateScreenshot(
                imageData: Data([0x01]),
                to: .simplifiedChinese
            )
        }
    }
}

@MainActor
private final class StubCompleter: LanguageModelCompleting {
    let content: String
    let supportsImageInput: Bool
    private(set) var requests: [LLMRequest] = []

    init(content: String, supportsImageInput: Bool = false) {
        self.content = content
        self.supportsImageInput = supportsImageInput
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        requests.append(request)
        return LLMResponse(content: content, model: "stub")
    }
}
