import Combine
import Foundation

@MainActor
final class ShortcutStore: ObservableObject {
    @Published private(set) var translationShortcut: GlobalShortcut?
    @Published private(set) var saveShortcut: GlobalShortcut?

    private let defaults: UserDefaults
    private let configurationKey = "shortcuts.configuration.v2"
    private let legacyTranslationKey = "translation.globalShortcut"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: configurationKey),
           let configuration = try? JSONDecoder().decode(
               ShortcutConfiguration.self,
               from: data
           ) {
            translationShortcut = Self.validated(configuration.translationShortcut)
            saveShortcut = Self.validated(configuration.saveShortcut)
        } else if let data = defaults.data(forKey: legacyTranslationKey),
                  let savedShortcut = try? JSONDecoder().decode(GlobalShortcut.self, from: data),
                  Self.validated(savedShortcut) != nil {
            translationShortcut = savedShortcut
            saveShortcut = nil
        } else {
            translationShortcut = .default
            saveShortcut = nil
        }
    }

    func setTranslationShortcut(_ shortcut: GlobalShortcut?) {
        guard translationShortcut != shortcut else { return }
        translationShortcut = shortcut
        persist()
    }

    func setSaveShortcut(_ shortcut: GlobalShortcut?) {
        guard saveShortcut != shortcut else { return }
        saveShortcut = shortcut
        persist()
    }

    private func persist() {
        let configuration = ShortcutConfiguration(
            translationShortcut: translationShortcut,
            saveShortcut: saveShortcut
        )
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: configurationKey)
    }

    private static func validated(_ shortcut: GlobalShortcut?) -> GlobalShortcut? {
        guard let shortcut,
              !shortcut.modifiers.isEmpty,
              !shortcut.keyDisplayName.isEmpty else {
            return nil
        }
        return shortcut
    }
}

private struct ShortcutConfiguration: Codable {
    let translationShortcut: GlobalShortcut?
    let saveShortcut: GlobalShortcut?
}
