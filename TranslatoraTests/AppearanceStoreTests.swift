import Foundation
import Testing
@testable import Translatora

@MainActor
struct AppearanceStoreTests {
    @Test
    func persistsAppearancePreference() {
        let suiteName = "TranslatoraTests.Appearance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppearanceStore(defaults: defaults)
        #expect(store.appearance == .system)

        store.setAppearance(.dark)

        #expect(store.appearance == .dark)
        #expect(AppearanceStore(defaults: defaults).appearance == .dark)
    }
}
