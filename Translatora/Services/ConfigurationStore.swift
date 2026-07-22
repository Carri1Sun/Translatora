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
        let legacyConfiguration = defaults === UserDefaults.standard
            ? Self.loadSandboxedConfigurationIfNeeded(defaults: defaults)
            : nil
        let apiKey = defaults.string(forKey: Keys.deepSeekAPIKey)
            ?? legacyConfiguration?.apiKey
            ?? ""
        let model = (defaults.string(forKey: Keys.deepSeekModel)
            ?? legacyConfiguration?.model.rawValue)
            .flatMap(DeepSeekModel.init(rawValue:)) ?? .v4Flash

        deepSeekConfiguration = DeepSeekConfiguration(apiKey: apiKey, model: model)

        if defaults.string(forKey: Keys.deepSeekAPIKey) == nil,
           let legacyConfiguration {
            defaults.set(legacyConfiguration.apiKey, forKey: Keys.deepSeekAPIKey)
            defaults.set(legacyConfiguration.model.rawValue, forKey: Keys.deepSeekModel)
        }
    }

    func saveDeepSeekConfiguration(_ configuration: DeepSeekConfiguration) {
        let configuration = configuration.normalized

        // TODO: 未来使用 Keychain 安全存储 API Key。
        defaults.set(configuration.apiKey, forKey: Keys.deepSeekAPIKey)
        defaults.set(configuration.model.rawValue, forKey: Keys.deepSeekModel)
        deepSeekConfiguration = configuration
    }

    private static func loadSandboxedConfigurationIfNeeded(
        defaults: UserDefaults
    ) -> DeepSeekConfiguration? {
        guard defaults.string(forKey: Keys.deepSeekAPIKey) == nil else { return nil }

        let bundleIdentifier = Bundle.main.bundleIdentifier
            ?? "com.kaiyisun.translatora.Translatora"
        let preferencesURL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Containers", directoryHint: .isDirectory)
            .appending(path: bundleIdentifier, directoryHint: .isDirectory)
            .appending(path: "Data/Library/Preferences", directoryHint: .isDirectory)
            .appending(path: "\(bundleIdentifier).plist", directoryHint: .notDirectory)

        guard let data = try? Data(contentsOf: preferencesURL),
              let propertyList = try? PropertyListSerialization.propertyList(
                  from: data,
                  format: nil
              ),
              let values = propertyList as? [String: Any],
              let apiKey = values[Keys.deepSeekAPIKey] as? String,
              !apiKey.isEmpty else {
            return nil
        }

        let model = (values[Keys.deepSeekModel] as? String)
            .flatMap(DeepSeekModel.init(rawValue:)) ?? .v4Flash
        return DeepSeekConfiguration(apiKey: apiKey, model: model)
    }
}
