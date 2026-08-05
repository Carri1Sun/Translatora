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
    private var globalHotKeyMonitor: GlobalHotKeyMonitor?
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

        let monitor = GlobalHotKeyMonitor()
        globalHotKeyMonitor = monitor
        if let shortcut = shortcutStore.translationShortcut {
            do {
                try monitor.start(shortcut: shortcut) { [weak panelController] in
                    panelController?.toggle()
                }
                shortcutErrorMessage = nil
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

        if let shortcut, shortcut == shortcutStore.saveShortcut {
            shortcutErrorMessage = "该快捷键已用于保存词汇，请先修改另一项快捷键。"
            return false
        }

        guard let monitor = globalHotKeyMonitor else {
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
    func updateSaveShortcut(_ shortcut: GlobalShortcut?) -> Bool {
        if let shortcut, shortcut == shortcutStore.translationShortcut {
            shortcutErrorMessage = "该快捷键已用于打开翻译浮窗，请先修改另一项快捷键。"
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
