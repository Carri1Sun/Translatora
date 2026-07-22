import Combine
import Foundation

@MainActor
final class AppDependencies: ObservableObject {
    let configurationStore: ConfigurationStore
    let modelProvider: ModelProvider
    let dictionaryStore: DictionaryStore
    let appearanceStore: AppearanceStore
    let selectedTextReader: SelectedTextReader
    let translationService: TranslationService

    @Published private(set) var shortcutErrorMessage: String?

    private var translationPanelController: TranslationPanelController?
    private var globalHotKeyMonitor: GlobalHotKeyMonitor?
    private var appearanceCancellable: AnyCancellable?
    private var hasStarted = false

    init() {
        let configurationStore = ConfigurationStore()
        self.configurationStore = configurationStore
        let modelProvider = ModelProvider(configurationStore: configurationStore)
        self.modelProvider = modelProvider
        dictionaryStore = DictionaryStore()
        appearanceStore = AppearanceStore()
        selectedTextReader = SelectedTextReader()
        translationService = TranslationService(modelProvider: modelProvider)
        observeAppearanceChanges()
    }

    init(configurationStore: ConfigurationStore) {
        self.configurationStore = configurationStore
        let modelProvider = ModelProvider(configurationStore: configurationStore)
        self.modelProvider = modelProvider
        dictionaryStore = DictionaryStore()
        appearanceStore = AppearanceStore()
        selectedTextReader = SelectedTextReader()
        translationService = TranslationService(modelProvider: modelProvider)
        observeAppearanceChanges()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        let panelController = TranslationPanelController(
            translationService: translationService,
            dictionaryStore: dictionaryStore,
            appearanceStore: appearanceStore,
            selectedTextReader: selectedTextReader
        )
        translationPanelController = panelController

        let monitor = GlobalHotKeyMonitor()
        do {
            try monitor.start { [weak panelController] in
                panelController?.toggle()
            }
            globalHotKeyMonitor = monitor
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

    private func observeAppearanceChanges() {
        appearanceCancellable = appearanceStore.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
    }
}
