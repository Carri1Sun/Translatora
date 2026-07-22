import Foundation

@MainActor
final class ModelProvider {
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

    private func currentProvider() -> any LLMProvider {
        DeepSeekProvider(configuration: configurationStore.deepSeekConfiguration)
    }
}
