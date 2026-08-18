import Foundation
import Testing
@testable import Translatora

@MainActor
struct TranslationPanelViewModelTests {
    @Test
    func onlyAllowsPanelResizeForCompletedResults() {
        let result = TranslationResult(translation: "你好", examples: [])

        #expect(!TranslationPhase.idle.allowsPanelResize)
        #expect(!TranslationPhase.loading.allowsPanelResize)
        #expect(!TranslationPhase.failure("失败").allowsPanelResize)
        #expect(TranslationPhase.result(result).allowsPanelResize)
    }

    @Test
    func automaticallyTranslatesSelectionButOnlySavesOnRequest() async throws {
        let dictionaryURL = FileManager.default.temporaryDirectory
            .appending(path: "TranslatoraPanelTests-\(UUID().uuidString).json")
        let dictionaryStore = DictionaryStore(fileURL: dictionaryURL)
        let viewModel = TranslationPanelViewModel(
            translationService: TranslationService(
                modelProvider: PanelCompleter()
            ),
            dictionaryStore: dictionaryStore
        )

        viewModel.prepare(selectedText: "Hello")
        #expect(viewModel.sourceLanguage == .english)
        #expect(viewModel.targetLanguage == .simplifiedChinese)

        viewModel.translateAutomaticallyIfNeeded()
        while viewModel.phase == .loading {
            await Task.yield()
        }

        #expect(viewModel.result?.translation == "你好")
        #expect(dictionaryStore.entries.isEmpty)

        let savedEntry = viewModel.saveResult()
        #expect(savedEntry != nil)
        #expect(dictionaryStore.entries.count == 1)
        #expect(dictionaryStore.entries.first?.sourceText == "Hello")

        viewModel.reset()
        #expect(viewModel.inputText.isEmpty)
        #expect(viewModel.phase == .idle)
        #expect(!viewModel.isSaved)
    }

    @Test
    func translatesAndSavesScreenshotInput() async throws {
        let dictionaryURL = FileManager.default.temporaryDirectory
            .appending(path: "TranslatoraScreenshotPanelTests-\(UUID().uuidString).json")
        let dictionaryStore = DictionaryStore(fileURL: dictionaryURL)
        let viewModel = TranslationPanelViewModel(
            translationService: TranslationService(
                modelProvider: ScreenshotPanelCompleter()
            ),
            dictionaryStore: dictionaryStore
        )
        let imageData = Data([0x89, 0x50, 0x4e, 0x47])

        viewModel.prepare(screenshotImageData: imageData)
        #expect(viewModel.isScreenshotInput)
        #expect(viewModel.canTranslate)
        viewModel.translateAutomaticallyIfNeeded()
        while viewModel.phase == .loading {
            await Task.yield()
        }

        #expect(viewModel.result?.translation == "一张问候语截图。")
        #expect(viewModel.result?.screenshotTranslation?.elements.count == 1)

        let savedEntry = try #require(viewModel.saveResult())
        #expect(savedEntry.sourceImageData == imageData)
        #expect(savedEntry.translatedText == "一张问候语截图。")
        #expect(savedEntry.screenshotElements.first?.sourceText == "Hello")
        #expect(DictionaryStore(fileURL: dictionaryURL).entries.first?.sourceImageData == imageData)
    }
}

@MainActor
private struct PanelCompleter: LanguageModelCompleting {
    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(
            content: "{\"translation\":\"你好\",\"examples\":[]}",
            model: "panel-stub"
        )
    }
}

@MainActor
private struct ScreenshotPanelCompleter: LanguageModelCompleting {
    let supportsImageInput = true

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(
            content: """
            {"summary":"一张问候语截图。","elements":[{"sourceText":"Hello","translatedText":"你好","context":"画面中央的问候语"}]}
            """,
            model: "screenshot-panel-stub"
        )
    }
}
