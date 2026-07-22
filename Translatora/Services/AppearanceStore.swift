import Combine
import Foundation

@MainActor
final class AppearanceStore: ObservableObject {
    @Published private(set) var appearance: AppAppearance

    private let defaults: UserDefaults
    private let key = "appearance.preference"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: key)
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
    }

    func setAppearance(_ appearance: AppAppearance) {
        defaults.set(appearance.rawValue, forKey: key)
        self.appearance = appearance
    }
}
