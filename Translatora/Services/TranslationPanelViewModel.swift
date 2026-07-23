import Combine
import Foundation

enum TranslationPhase: Equatable {
    case idle
    case loading
    case result(TranslationResult)
    case failure(String)
}

@MainActor
final class TranslationPanelViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var sourceLanguage = TranslationLanguage.english
    @Published var targetLanguage = TranslationLanguage.simplifiedChinese
    @Published private(set) var phase = TranslationPhase.idle
    @Published private(set) var isSaved = false
    @Published private(set) var saveErrorMessage: String?

    private let translationService: TranslationService
    private let dictionaryStore: DictionaryStore
    private var translationTask: Task<Void, Never>?

    init(
        translationService: TranslationService,
        dictionaryStore: DictionaryStore
    ) {
        self.translationService = translationService
        self.dictionaryStore = dictionaryStore
    }

    var canTranslate: Bool {
        !normalizedInput.isEmpty && phase != .loading
    }

    var result: TranslationResult? {
        guard case let .result(result) = phase else { return nil }
        return result
    }

    func prepare(selectedText: String?) {
        reset()
        inputText = selectedText ?? ""
    }

    func translateAutomaticallyIfNeeded() {
        guard !normalizedInput.isEmpty else { return }
        translate()
    }

    func translate() {
        let text = normalizedInput
        guard !text.isEmpty, phase != .loading else { return }

        translationTask?.cancel()
        isSaved = false
        saveErrorMessage = nil
        phase = .loading

        let sourceLanguage = sourceLanguage
        let targetLanguage = targetLanguage
        translationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await translationService.translate(
                    text,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                try Task.checkCancellation()
                guard !result.translation.isEmpty else {
                    phase = .failure("模型没有返回翻译内容")
                    return
                }
                phase = .result(result)
            } catch is CancellationError {
                return
            } catch {
                phase = .failure(error.localizedDescription)
            }
        }
    }

    @discardableResult
    func saveResult() -> DictionaryEntry? {
        guard let result, !isSaved else { return nil }

        do {
            let entry = try dictionaryStore.add(
                sourceText: normalizedInput,
                translatedText: result.translation,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                examples: result.examples
            )
            isSaved = true
            saveErrorMessage = nil
            return entry
        } catch {
            saveErrorMessage = error.localizedDescription
            return nil
        }
    }

    func swapLanguages() {
        guard phase != .loading else { return }
        (sourceLanguage, targetLanguage) = (targetLanguage, sourceLanguage)
        if let result {
            inputText = result.translation
        }
        phase = .idle
        isSaved = false
    }

    func inputDidChange() {
        guard phase != .idle else { return }
        translationTask?.cancel()
        phase = .idle
        isSaved = false
        saveErrorMessage = nil
    }

    func translationOptionsDidChange() {
        inputDidChange()
    }

    func reset() {
        translationTask?.cancel()
        translationTask = nil
        inputText = ""
        phase = .idle
        isSaved = false
        saveErrorMessage = nil
    }

    private var normalizedInput: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
