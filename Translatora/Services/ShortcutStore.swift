import Combine
import Foundation

@MainActor
final class ShortcutStore: ObservableObject {
    @Published private(set) var translationShortcut: GlobalShortcut?
    @Published private(set) var screenshotShortcut: GlobalShortcut?
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
            let translationShortcut = Self.validated(configuration.translationShortcut)
            let saveShortcut = Self.validated(configuration.saveShortcut)
            let screenshotShortcut = Self.validated(configuration.screenshotShortcut)
            self.translationShortcut = translationShortcut
            self.saveShortcut = saveShortcut
            self.screenshotShortcut = screenshotShortcut == translationShortcut
                || screenshotShortcut == saveShortcut
                ? nil
                : screenshotShortcut
        } else if let data = defaults.data(forKey: legacyTranslationKey),
                  let savedShortcut = try? JSONDecoder().decode(GlobalShortcut.self, from: data),
                  Self.validated(savedShortcut) != nil {
            translationShortcut = savedShortcut
            screenshotShortcut = savedShortcut == .screenshotDefault
                ? nil
                : .screenshotDefault
            saveShortcut = nil
        } else {
            translationShortcut = .default
            screenshotShortcut = .screenshotDefault
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

    func setScreenshotShortcut(_ shortcut: GlobalShortcut?) {
        guard screenshotShortcut != shortcut else { return }
        screenshotShortcut = shortcut
        persist()
    }

    private func persist() {
        let configuration = ShortcutConfiguration(
            translationShortcut: translationShortcut,
            screenshotShortcut: screenshotShortcut,
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
    let screenshotShortcut: GlobalShortcut?
    let saveShortcut: GlobalShortcut?

    init(
        translationShortcut: GlobalShortcut?,
        screenshotShortcut: GlobalShortcut?,
        saveShortcut: GlobalShortcut?
    ) {
        self.translationShortcut = translationShortcut
        self.screenshotShortcut = screenshotShortcut
        self.saveShortcut = saveShortcut
    }

    private enum CodingKeys: String, CodingKey {
        case translationShortcut
        case screenshotShortcut
        case saveShortcut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        translationShortcut = try container.decodeIfPresent(
            GlobalShortcut.self,
            forKey: .translationShortcut
        )
        if container.contains(.screenshotShortcut) {
            screenshotShortcut = try container.decodeIfPresent(
                GlobalShortcut.self,
                forKey: .screenshotShortcut
            )
        } else {
            screenshotShortcut = .screenshotDefault
        }
        saveShortcut = try container.decodeIfPresent(
            GlobalShortcut.self,
            forKey: .saveShortcut
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(translationShortcut, forKey: .translationShortcut)
        if let screenshotShortcut {
            try container.encode(screenshotShortcut, forKey: .screenshotShortcut)
        } else {
            try container.encodeNil(forKey: .screenshotShortcut)
        }
        try container.encodeIfPresent(saveShortcut, forKey: .saveShortcut)
    }
}
