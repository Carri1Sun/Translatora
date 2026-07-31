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
                model: .m27Highspeed
            )
        )
        store.selectProvider(.miniMax)

        let restoredStore = ConfigurationStore(defaults: defaults)

        #expect(restoredStore.selectedProvider == .miniMax)
        #expect(restoredStore.miniMaxConfiguration.apiKey == "minimax-key")
        #expect(restoredStore.miniMaxConfiguration.model == .m27Highspeed)
    }

    @Test
    func defaultsToDeepSeekForExistingUsers() {
        let suiteName = "ConfigurationStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("existing-key", forKey: "deepseek.apiKey")

        let store = ConfigurationStore(defaults: defaults)

        #expect(store.selectedProvider == .deepSeek)
        #expect(store.deepSeekConfiguration.apiKey == "existing-key")
        #expect(store.miniMaxConfiguration.model == .m3)
    }
}
