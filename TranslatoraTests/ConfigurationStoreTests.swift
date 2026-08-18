import Foundation
import Testing
@testable import Translatora

@MainActor
struct ConfigurationStoreTests {
    @Test
    func persistsSelectedProviderAndMiniMaxConfiguration() {
        let suiteName = "ConfigurationStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ConfigurationStore(defaults: defaults)
        store.saveMiniMaxConfiguration(
            MiniMaxConfiguration(
                apiKey: "  minimax-key  ",
                model: .m27Highspeed,
                ttsVoice: .femaleYujie
            )
        )
        store.selectLanguageProvider(.miniMax)
        store.selectTTSProvider(.miniMax)

        let restoredStore = ConfigurationStore(defaults: defaults)

        #expect(restoredStore.selectedLanguageProvider == .miniMax)
        #expect(restoredStore.selectedTTSProvider == .miniMax)
        #expect(restoredStore.miniMaxConfiguration.apiKey == "minimax-key")
        #expect(restoredStore.miniMaxConfiguration.model == .m27Highspeed)
        #expect(restoredStore.miniMaxConfiguration.ttsVoice == .femaleYujie)
    }

    @Test
    func defaultsToDeepSeekForExistingUsers() {
        let suiteName = "ConfigurationStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("existing-key", forKey: "deepseek.apiKey")

        let store = ConfigurationStore(defaults: defaults)

        #expect(store.selectedLanguageProvider == .deepSeek)
        #expect(store.selectedTTSProvider == .qwen)
        #expect(store.deepSeekConfiguration.apiKey == "existing-key")
        #expect(store.miniMaxConfiguration.model == .m3)
        #expect(store.qwenConfiguration.model == .v38Max)
        #expect(store.qwenConfiguration.region == .international)
        #expect(store.miniMaxConfiguration.ttsVoice == .automatic)
        #expect(store.qwenConfiguration.ttsVoice == .longXiaochun)
    }

    @Test
    func persistsQwenTokenPlanConfiguration() {
        let suiteName = "ConfigurationStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ConfigurationStore(defaults: defaults)
        store.saveQwenConfiguration(
            QwenConfiguration(
                apiKey: "  qwen-key  ",
                model: .v36Flash,
                region: .china,
                ttsVoice: .longAnLufeng
            )
        )
        store.selectLanguageProvider(.qwen)

        let restoredStore = ConfigurationStore(defaults: defaults)

        #expect(restoredStore.selectedLanguageProvider == .qwen)
        #expect(restoredStore.qwenConfiguration.apiKey == "qwen-key")
        #expect(restoredStore.qwenConfiguration.model == .v36Flash)
        #expect(restoredStore.qwenConfiguration.region == .china)
        #expect(restoredStore.qwenConfiguration.ttsVoice == .longAnLufeng)
    }

    @Test
    func reportsImageInputCapabilityForSelectedModel() {
        let suiteName = "ConfigurationStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ConfigurationStore(defaults: defaults)
        let router = LanguageModelProviderRouter(configurationStore: store)

        #expect(!router.supportsImageInput)

        store.selectLanguageProvider(.qwen)
        #expect(router.supportsImageInput)

        store.selectLanguageProvider(.miniMax)
        #expect(!router.supportsImageInput)
    }
}
