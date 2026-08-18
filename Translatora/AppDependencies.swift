import AppKit
import Combine
import Foundation

@MainActor
final class AppDependencies: ObservableObject {
    let configurationStore: ConfigurationStore
    let languageModelProvider: LanguageModelProviderRouter
    let ttsProvider: TTSProviderRouter
    let pronunciationService: PronunciationService
    let dictionaryStore: DictionaryStore
    let appearanceStore: AppearanceStore
    let menuBarStore: MenuBarStore
    let shortcutStore: ShortcutStore
    let selectedTextReader: SelectedTextReader
    let translationService: TranslationService

    @Published private(set) var shortcutErrorMessage: String?
    @Published private(set) var isSettingsPresented = false
    @Published private(set) var requestedDictionaryEntryID: UUID?

    private var translationPanelController: TranslationPanelController?
    private var translationHotKeyMonitor: GlobalHotKeyMonitor?
    private var screenshotHotKeyMonitor: GlobalHotKeyMonitor?
    private let screenshotSelectionController = ScreenshotSelectionController()
    private let centerToastController = CenterToastController()
    private let mainWindowController = MainWindowController()
    private var appearanceCancellable: AnyCancellable?
    private var menuBarCancellable: AnyCancellable?
    private var shortcutCancellable: AnyCancellable?
    private var hasStarted = false

    init() {
        let configurationStore = ConfigurationStore()
        self.configurationStore = configurationStore
        let languageModelProvider = LanguageModelProviderRouter(
            configurationStore: configurationStore
        )
        self.languageModelProvider = languageModelProvider
        let ttsProvider = TTSProviderRouter(configurationStore: configurationStore)
        self.ttsProvider = ttsProvider
        pronunciationService = PronunciationService(
            ttsProvider: ttsProvider,
            cache: SpeechAudioCache()
        )
        dictionaryStore = DictionaryStore()
        appearanceStore = AppearanceStore()
        menuBarStore = MenuBarStore()
        shortcutStore = ShortcutStore()
        selectedTextReader = SelectedTextReader()
        translationService = TranslationService(modelProvider: languageModelProvider)
        observeAppearanceChanges()
        observeMenuBarChanges()
        observeShortcutChanges()
    }

    init(configurationStore: ConfigurationStore) {
        self.configurationStore = configurationStore
        let languageModelProvider = LanguageModelProviderRouter(
            configurationStore: configurationStore
        )
        self.languageModelProvider = languageModelProvider
        let ttsProvider = TTSProviderRouter(configurationStore: configurationStore)
        self.ttsProvider = ttsProvider
        pronunciationService = PronunciationService(
            ttsProvider: ttsProvider,
            cache: SpeechAudioCache()
        )
        dictionaryStore = DictionaryStore()
        appearanceStore = AppearanceStore()
        menuBarStore = MenuBarStore()
        shortcutStore = ShortcutStore()
        selectedTextReader = SelectedTextReader()
        translationService = TranslationService(modelProvider: languageModelProvider)
        observeAppearanceChanges()
        observeMenuBarChanges()
        observeShortcutChanges()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        let panelController = TranslationPanelController(
            translationService: translationService,
            dictionaryStore: dictionaryStore,
            appearanceStore: appearanceStore,
            shortcutStore: shortcutStore,
            selectedTextReader: selectedTextReader,
            pronunciationService: pronunciationService,
            onViewDictionaryEntry: { [weak self] entryID in
                self?.showDictionaryEntry(entryID)
            }
        )
        translationPanelController = panelController

        let translationMonitor = GlobalHotKeyMonitor()
        translationHotKeyMonitor = translationMonitor
        if let shortcut = shortcutStore.translationShortcut {
            do {
                try translationMonitor.start(shortcut: shortcut) { [weak panelController] in
                    panelController?.toggle()
                }
                shortcutErrorMessage = nil
            } catch {
                shortcutErrorMessage = error.localizedDescription
            }
        }

        let screenshotMonitor = GlobalHotKeyMonitor()
        screenshotHotKeyMonitor = screenshotMonitor
        if let shortcut = shortcutStore.screenshotShortcut {
            do {
                try screenshotMonitor.start(shortcut: shortcut) { [weak self] in
                    self?.toggleScreenshotTranslation()
                }
            } catch {
                shortcutErrorMessage = error.localizedDescription
            }
        }
    }

    func toggleTranslationPanel() {
        if !hasStarted {
            start()
        }
        translationPanelController?.toggle()
    }

    func toggleScreenshotTranslation() {
        if !hasStarted {
            start()
        }

        if screenshotSelectionController.isSelecting {
            screenshotSelectionController.cancel()
            return
        }

        guard languageModelProvider.supportsImageInput else {
            centerToastController.show(message: "当前模型不支持截图翻译")
            return
        }

        translationPanelController?.close()
        screenshotSelectionController.start(
            onCaptured: { [weak self] imageData in
                self?.translationPanelController?.show(screenshotImageData: imageData)
            },
            onError: { [weak self] message in
                self?.centerToastController.show(message: message)
            }
        )
    }

    func attachMainWindow(_ window: NSWindow) {
        mainWindowController.attach(window)
    }

    @discardableResult
    func showMainWindow() -> Bool {
        mainWindowController.show()
    }

    func presentSettings() {
        isSettingsPresented = true
    }

    func dismissSettings() {
        isSettingsPresented = false
    }

    @discardableResult
    func updateTranslationShortcut(_ shortcut: GlobalShortcut?) -> Bool {
        if !hasStarted {
            start()
        }

        if let conflict = shortcutConflict(
            for: shortcut,
            excluding: .translation
        ) {
            shortcutErrorMessage = conflict
            return false
        }

        guard let monitor = translationHotKeyMonitor else {
            shortcutErrorMessage = "无法初始化全局快捷键监听。"
            return false
        }

        guard let shortcut else {
            monitor.stop()
            shortcutStore.setTranslationShortcut(nil)
            shortcutErrorMessage = nil
            return true
        }

        do {
            if monitor.isStarted {
                try monitor.updateShortcut(shortcut)
            } else {
                let panelController = translationPanelController
                try monitor.start(shortcut: shortcut) { [weak panelController] in
                    panelController?.toggle()
                }
            }
            shortcutStore.setTranslationShortcut(shortcut)
            shortcutErrorMessage = nil
            return true
        } catch {
            shortcutErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func updateScreenshotShortcut(_ shortcut: GlobalShortcut?) -> Bool {
        if !hasStarted {
            start()
        }

        if let conflict = shortcutConflict(
            for: shortcut,
            excluding: .screenshot
        ) {
            shortcutErrorMessage = conflict
            return false
        }

        guard let monitor = screenshotHotKeyMonitor else {
            shortcutErrorMessage = "无法初始化全局快捷键监听。"
            return false
        }

        guard let shortcut else {
            monitor.stop()
            shortcutStore.setScreenshotShortcut(nil)
            shortcutErrorMessage = nil
            return true
        }

        do {
            if monitor.isStarted {
                try monitor.updateShortcut(shortcut)
            } else {
                try monitor.start(shortcut: shortcut) { [weak self] in
                    self?.toggleScreenshotTranslation()
                }
            }
            shortcutStore.setScreenshotShortcut(shortcut)
            shortcutErrorMessage = nil
            return true
        } catch {
            shortcutErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func updateSaveShortcut(_ shortcut: GlobalShortcut?) -> Bool {
        if let conflict = shortcutConflict(for: shortcut, excluding: .save) {
            shortcutErrorMessage = conflict
            return false
        }

        shortcutStore.setSaveShortcut(shortcut)
        shortcutErrorMessage = nil
        return true
    }

    func consumeRequestedDictionaryEntry() {
        requestedDictionaryEntryID = nil
    }

    private func showDictionaryEntry(_ entryID: UUID) {
        isSettingsPresented = false
        requestedDictionaryEntryID = entryID
        _ = showMainWindow()
    }

    private enum ShortcutPurpose: Equatable {
        case translation
        case screenshot
        case save
    }

    private func shortcutConflict(
        for shortcut: GlobalShortcut?,
        excluding purpose: ShortcutPurpose
    ) -> String? {
        guard let shortcut else { return nil }

        if purpose != .translation, shortcut == shortcutStore.translationShortcut {
            return "该快捷键已用于打开翻译浮窗，请先修改另一项快捷键。"
        }
        if purpose != .screenshot, shortcut == shortcutStore.screenshotShortcut {
            return "该快捷键已用于截图翻译，请先修改另一项快捷键。"
        }
        if purpose != .save, shortcut == shortcutStore.saveShortcut {
            return "该快捷键已用于保存词汇，请先修改另一项快捷键。"
        }
        return nil
    }

    private func observeAppearanceChanges() {
        appearanceCancellable = appearanceStore.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
    }

    private func observeMenuBarChanges() {
        menuBarCancellable = menuBarStore.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
    }

    private func observeShortcutChanges() {
        shortcutCancellable = shortcutStore.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
    }
}
