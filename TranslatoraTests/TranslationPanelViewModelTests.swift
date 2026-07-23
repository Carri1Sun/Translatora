import Foundation
import Testing
@testable import Translatora

@MainActor
struct TranslationPanelViewModelTests {
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
}

@MainActor
private struct PanelCompleter: LLMCompleting {
    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(
            content: "{\"translation\":\"你好\",\"examples\":[]}",
            model: "panel-stub"
        )
    }
}
