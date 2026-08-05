import AppKit
import SwiftUI
import Testing
@testable import Translatora

@MainActor
struct RenderingSmokeTests {
    @Test
    func rendersMainDictionaryWindow() throws {
        let dictionaryURL = FileManager.default.temporaryDirectory
            .appending(path: "TranslatoraMainRender-\(UUID().uuidString).json")
        let dictionaryStore = DictionaryStore(fileURL: dictionaryURL)
        try dictionaryStore.add(
            sourceText: "serendipity",
            translatedText: "意外发现美好事物的幸运",
            sourceLanguage: .english,
            targetLanguage: .simplifiedChinese,
            examples: []
        )
        var secondEntry = try dictionaryStore.add(
            sourceText: "The early bird catches the worm.",
            translatedText: "早起的鸟儿有虫吃。",
            sourceLanguage: .english,
            targetLanguage: .simplifiedChinese,
            examples: []
        )
        secondEntry.createdAt = Calendar.current.date(
            byAdding: .day,
            value: -1,
            to: .now
        )!
        secondEntry.note = "提醒自己主动把握机会。"
        try dictionaryStore.update(secondEntry)
        try dictionaryStore.add(
            sourceText: "Less is more.",
            translatedText: "少即是多。",
            sourceLanguage: .english,
            targetLanguage: .simplifiedChinese,
            examples: []
        )

        let view = DictionaryHomeView(
            dictionaryStore: dictionaryStore,
            shortcutStore: ShortcutStore(
                defaults: UserDefaults(suiteName: "TranslatoraRender.Shortcut.Main")!
            ),
            shortcutErrorMessage: nil
        )
            .environmentObject(AppDependencies())
            .preferredColorScheme(.light)
            .frame(width: 980, height: 720)

        let pngData = try render(view, size: NSSize(width: 980, height: 720))
        #expect(pngData.count > 10_000)
        try pngData.write(to: URL(filePath: "/tmp/translatora-main-render.png"), options: .atomic)
    }

    @Test
    func rendersDictionaryEntryDetail() throws {
        let entry = DictionaryEntry(
            sourceText: "The early bird catches the worm.",
            translatedText: "早起的鸟儿有虫吃。",
            note: "提醒自己主动把握机会，也可以用来鼓励尽早行动。",
            sourceLanguage: .english,
            targetLanguage: .simplifiedChinese,
            examples: [
                TranslationExample(
                    source: "She starts work at dawn—the early bird catches the worm.",
                    translation: "她黎明就开始工作——早起的鸟儿有虫吃。"
                ),
                TranslationExample(
                    source: "Book your tickets now; the early bird catches the worm.",
                    translation: "现在就订票吧，早行动的人更有机会。"
                )
            ]
        )

        let view = DictionaryEntryDetailView(
            entry: entry,
            position: 2,
            totalCount: 6,
            canGoPrevious: true,
            canGoNext: true,
            onPrevious: {},
            onNext: {},
            onSave: { _ in true },
            onDelete: { _ in true },
            onClose: {}
        )
        .preferredColorScheme(.light)
        .background(Color.white)

        let pngData = try render(view, size: NSSize(width: 680, height: 660))
        #expect(pngData.count > 10_000)
        try pngData.write(to: URL(filePath: "/tmp/translatora-detail-render.png"), options: .atomic)
    }

    @Test
    func rendersSettingsCard() throws {
        let suiteName = "TranslatoraRender.Settings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let configurationStore = ConfigurationStore(defaults: defaults)
        configurationStore.saveQwenConfiguration(
            QwenConfiguration(
                apiKey: "render-token-plan-key",
                model: .v38Max,
                region: .international
            )
        )
        configurationStore.selectProvider(.qwen)

        let view = SettingsCardView(
            configurationStore: configurationStore,
            modelProvider: ModelProvider(configurationStore: configurationStore),
            appearanceStore: AppearanceStore(defaults: defaults),
            menuBarStore: MenuBarStore(defaults: defaults),
            shortcutStore: ShortcutStore(defaults: defaults),
            shortcutErrorMessage: nil,
            updateTranslationShortcut: { _ in true },
            updateSaveShortcut: { _ in true },
            selectedTextReader: SelectedTextReader(),
            onClose: {}
        )
        .preferredColorScheme(.light)
        .frame(width: 760, height: 620)
        .clipShape(.rect(cornerRadius: 22))
        .background(Color.white)

        let pngData = try render(view, size: NSSize(width: 760, height: 620))
        #expect(pngData.count > 10_000)
        try pngData.write(to: URL(filePath: "/tmp/translatora-settings-render.png"), options: .atomic)
    }

    @Test
    func rendersQwenProviderSettings() throws {
        let suiteName = "TranslatoraRender.QwenSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let configurationStore = ConfigurationStore(defaults: defaults)
        configurationStore.saveQwenConfiguration(
            QwenConfiguration(
                apiKey: "render-token-plan-key",
                model: .v38Max,
                region: .international
            )
        )
        configurationStore.selectProvider(.qwen)

        let view = ModelProviderSettingsView(
            configurationStore: configurationStore,
            modelProvider: ModelProvider(configurationStore: configurationStore)
        )
        .preferredColorScheme(.light)
        .frame(width: 540, height: 560)
        .background(Color.white)

        let pngData = try render(view, size: NSSize(width: 540, height: 560))
        #expect(pngData.count > 10_000)
        try pngData.write(
            to: URL(filePath: "/tmp/translatora-qwen-settings-render.png"),
            options: .atomic
        )
    }

    @Test
    func rendersTranslationResultPanel() async throws {
        let temporaryDictionaryURL = FileManager.default.temporaryDirectory
            .appending(path: "TranslatoraRender-\(UUID().uuidString).json")
        let dictionaryStore = DictionaryStore(fileURL: temporaryDictionaryURL)
        let viewModel = TranslationPanelViewModel(
            translationService: TranslationService(
                modelProvider: RenderCompleter()
            ),
            dictionaryStore: dictionaryStore
        )
        viewModel.inputText = "The early bird catches the worm."
        viewModel.translate()

        while viewModel.phase == .loading {
            await Task.yield()
        }

        let appearanceDefaults = UserDefaults(suiteName: "TranslatoraRender.Appearance")!
        let appearanceStore = AppearanceStore(defaults: appearanceDefaults)
        appearanceStore.setAppearance(.dark)

        let view = TranslationPanelView(
            viewModel: viewModel,
            appearanceStore: appearanceStore,
            shortcutStore: ShortcutStore(
                defaults: UserDefaults(suiteName: "TranslatoraRender.Shortcut.Panel")!
            ),
            onClose: {},
            onSaved: { _ in }
        )
        .environment(\.colorScheme, .dark)
        .frame(width: 640, height: 650)

        let pngData = try render(view, size: NSSize(width: 640, height: 650))
        #expect(pngData.count > 10_000)
        try pngData.write(to: URL(filePath: "/tmp/translatora-panel-render.png"), options: .atomic)
    }

    private func render<Content: View>(
        _ content: Content,
        size: NSSize
    ) throws -> Data {
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw RenderingError.bitmapUnavailable
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderingError.pngUnavailable
        }
        return data
    }
}

@MainActor
private struct RenderCompleter: LLMCompleting {
    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(
            content: """
            {"translation":"早起的鸟儿有虫吃。","examples":[{"source":"She starts work at dawn—the early bird catches the worm.","translation":"她黎明就开始工作——早起的鸟儿有虫吃。"}]}
            """,
            model: "render-stub"
        )
    }
}

private enum RenderingError: Error {
    case bitmapUnavailable
    case pngUnavailable
}
