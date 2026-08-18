import Foundation

@MainActor
final class LanguageModelProviderRouter: LanguageModelCompleting {
    private let configurationStore: ConfigurationStore

    init(configurationStore: ConfigurationStore) {
        self.configurationStore = configurationStore
    }

    var supportsImageInput: Bool {
        switch configurationStore.selectedLanguageProvider {
        case .deepSeek:
            configurationStore.deepSeekConfiguration.model.supportsImageInput
        case .miniMax:
            configurationStore.miniMaxConfiguration.model.supportsImageInput
        case .qwen:
            configurationStore.qwenConfiguration.model.supportsImageInput
        }
    }

    var currentModelDisplayName: String {
        switch configurationStore.selectedLanguageProvider {
        case .deepSeek:
            configurationStore.deepSeekConfiguration.model.displayName
        case .miniMax:
            configurationStore.miniMaxConfiguration.model.displayName
        case .qwen:
            configurationStore.qwenConfiguration.model.displayName
        }
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        try await currentProvider().complete(request)
    }

    func testConnection(using configuration: DeepSeekConfiguration? = nil) async throws {
        let provider = DeepSeekProvider(
            configuration: configuration ?? configurationStore.deepSeekConfiguration
        )
        try await provider.testConnection()
    }

    func testConnection(using configuration: MiniMaxConfiguration) async throws {
        try await MiniMaxProvider(configuration: configuration).testConnection()
    }

    func testConnection(using configuration: QwenConfiguration) async throws {
        try await QwenProvider(configuration: configuration).testConnection()
    }

    private func currentProvider() -> any LanguageModelProvider {
        switch configurationStore.selectedLanguageProvider {
        case .deepSeek:
            DeepSeekProvider(configuration: configurationStore.deepSeekConfiguration)
        case .miniMax:
            MiniMaxProvider(configuration: configurationStore.miniMaxConfiguration)
        case .qwen:
            QwenProvider(configuration: configurationStore.qwenConfiguration)
        }
    }
}
