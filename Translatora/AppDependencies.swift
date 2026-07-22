import Combine
import Foundation

@MainActor
final class AppDependencies: ObservableObject {
    let configurationStore: ConfigurationStore
    let modelProvider: ModelProvider
    let dictionaryStore: DictionaryStore
    let appearanceStore: AppearanceStore
    let shortcutStore: ShortcutStore
    let selectedTextReader: SelectedTextReader
    let translationService: TranslationService

    @Published private(set) var shortcutErrorMessage: String?

    private var translationPanelController: TranslationPanelController?
    private var globalHotKeyMonitor: GlobalHotKeyMonitor?
    private var appearanceCancellable: AnyCancellable?
    private var shortcutCancellable: AnyCancellable?
    private var hasStarted = false

    init() {
        let configurationStore = ConfigurationStore()
        self.configurationStore = configurationStore
        let modelProvider = ModelProvider(configurationStore: configurationStore)
        self.modelProvider = modelProvider
        dictionaryStore = DictionaryStore()
        appearanceStore = AppearanceStore()
        shortcutStore = ShortcutStore()
        selectedTextReader = SelectedTextReader()
        translationService = TranslationService(modelProvider: modelProvider)
        observeAppearanceChanges()
        observeShortcutChanges()
    }

    init(configurationStore: ConfigurationStore) {
        self.configurationStore = configurationStore
        let modelProvider = ModelProvider(configurationStore: configurationStore)
        self.modelProvider = modelProvider
        dictionaryStore = DictionaryStore()
        appearanceStore = AppearanceStore()
        shortcutStore = ShortcutStore()
        selectedTextReader = SelectedTextReader()
        translationService = TranslationService(modelProvider: modelProvider)
        observeAppearanceChanges()
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
            selectedTextReader: selectedTextReader
        )
        translationPanelController = panelController

        let monitor = GlobalHotKeyMonitor()
        globalHotKeyMonitor = monitor
        do {
            try monitor.start(shortcut: shortcutStore.shortcut) { [weak panelController] in
                panelController?.toggle()
            }
            shortcutErrorMessage = nil
        } catch {
            shortcutErrorMessage = error.localizedDescription
        }
    }

    func toggleTranslationPanel() {
        if !hasStarted {
            start()
        }
        translationPanelController?.toggle()
    }

    @discardableResult
    func updateGlobalShortcut(_ shortcut: GlobalShortcut) -> Bool {
        if !hasStarted {
            start()
        }

        guard let monitor = globalHotKeyMonitor else {
            shortcutErrorMessage = "无法初始化全局快捷键监听。"
            return false
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
            shortcutStore.setShortcut(shortcut)
            shortcutErrorMessage = nil
            return true
        } catch {
            shortcutErrorMessage = error.localizedDescription
            return false
        }
    }

    private func observeAppearanceChanges() {
        appearanceCancellable = appearanceStore.objectWillChange
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
