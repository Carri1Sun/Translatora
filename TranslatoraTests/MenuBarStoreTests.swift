import Foundation
import Testing
@testable import Translatora

@MainActor
struct MenuBarStoreTests {
    @Test
    func defaultsToVisibleAndPersistsChanges() {
        let suiteName = "TranslatoraTests.MenuBar.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = MenuBarStore(defaults: defaults)
        #expect(store.isVisible)

        store.setVisible(false)

        #expect(!store.isVisible)
        #expect(!MenuBarStore(defaults: defaults).isVisible)
    }
}
