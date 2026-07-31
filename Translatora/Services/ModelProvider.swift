import Foundation

@MainActor
final class ModelProvider: LLMCompleting {
    private let configurationStore: ConfigurationStore

    init(configurationStore: ConfigurationStore) {
        self.configurationStore = configurationStore
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

    private func currentProvider() -> any LLMProvider {
        switch configurationStore.selectedProvider {
        case .deepSeek:
            DeepSeekProvider(configuration: configurationStore.deepSeekConfiguration)
        case .miniMax:
            MiniMaxProvider(configuration: configurationStore.miniMaxConfiguration)
        }
    }
}
