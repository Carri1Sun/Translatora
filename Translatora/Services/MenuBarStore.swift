import Combine
import Foundation

@MainActor
final class MenuBarStore: ObservableObject {
    @Published private(set) var isVisible: Bool

    private let defaults: UserDefaults
    private let key = "menuBar.isVisible"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isVisible = defaults.object(forKey: key) as? Bool ?? true
    }

    func setVisible(_ isVisible: Bool) {
        guard self.isVisible != isVisible else { return }
        defaults.set(isVisible, forKey: key)
        self.isVisible = isVisible
    }
}
