import Combine
import Foundation

@MainActor
final class ShortcutStore: ObservableObject {
    @Published private(set) var shortcut: GlobalShortcut

    private let defaults: UserDefaults
    private let key = "translation.globalShortcut"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: key),
           let savedShortcut = try? JSONDecoder().decode(GlobalShortcut.self, from: data),
           !savedShortcut.modifiers.isEmpty,
           !savedShortcut.keyDisplayName.isEmpty {
            shortcut = savedShortcut
        } else {
            shortcut = .default
        }
    }

    func setShortcut(_ shortcut: GlobalShortcut) {
        guard self.shortcut != shortcut else { return }
        if let data = try? JSONEncoder().encode(shortcut) {
            defaults.set(data, forKey: key)
        }
        self.shortcut = shortcut
    }
}
