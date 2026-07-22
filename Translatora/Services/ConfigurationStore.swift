import Combine
import Foundation

@MainActor
final class ConfigurationStore: ObservableObject {
    @Published private(set) var deepSeekConfiguration: DeepSeekConfiguration

    private enum Keys {
        static let deepSeekAPIKey = "deepseek.apiKey"
        static let deepSeekModel = "deepseek.model"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // TODO: 未来使用 Keychain 安全存储 API Key。
        let apiKey = defaults.string(forKey: Keys.deepSeekAPIKey) ?? ""
        let model = defaults.string(forKey: Keys.deepSeekModel)
            .flatMap(DeepSeekModel.init(rawValue:)) ?? .v4Flash

        deepSeekConfiguration = DeepSeekConfiguration(apiKey: apiKey, model: model)
    }

    func saveDeepSeekConfiguration(_ configuration: DeepSeekConfiguration) {
        let configuration = configuration.normalized

        // TODO: 未来使用 Keychain 安全存储 API Key。
        defaults.set(configuration.apiKey, forKey: Keys.deepSeekAPIKey)
        defaults.set(configuration.model.rawValue, forKey: Keys.deepSeekModel)
        deepSeekConfiguration = configuration
    }
}
