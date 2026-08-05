import Foundation

@MainActor
final class TTSProviderRouter: TTSSynthesizing {
    private let configurationStore: ConfigurationStore

    init(configurationStore: ConfigurationStore) {
        self.configurationStore = configurationStore
    }

    func synthesize(_ request: TTSRequest) async throws -> TTSResponse {
        try await currentProvider().synthesize(request)
    }

    private func currentProvider() -> any TTSProvider {
        switch configurationStore.selectedTTSProvider {
        case .qwen:
            QwenTTSProvider(configuration: configurationStore.qwenConfiguration)
        case .miniMax:
            MiniMaxTTSProvider(configuration: configurationStore.miniMaxConfiguration)
        }
    }
}
