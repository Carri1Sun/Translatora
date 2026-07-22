import Combine
import Foundation

@MainActor
final class AppDependencies: ObservableObject {
    let configurationStore: ConfigurationStore
    let modelProvider: ModelProvider

    init() {
        let configurationStore = ConfigurationStore()
        self.configurationStore = configurationStore
        modelProvider = ModelProvider(configurationStore: configurationStore)
    }

    init(configurationStore: ConfigurationStore) {
        self.configurationStore = configurationStore
        modelProvider = ModelProvider(configurationStore: configurationStore)
    }
}
