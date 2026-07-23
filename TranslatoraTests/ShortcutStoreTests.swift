import Carbon
import Foundation
import Testing
@testable import Translatora

@MainActor
struct ShortcutStoreTests {
    @Test
    func defaultsAndPersistsOptionalShortcuts() {
        let suiteName = "TranslatoraTests.Shortcuts.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ShortcutStore(defaults: defaults)
        #expect(store.translationShortcut == .default)
        #expect(store.saveShortcut == nil)

        let saveShortcut = GlobalShortcut(
            keyCode: UInt32(kVK_ANSI_S),
            keyDisplayName: "S",
            modifiers: [.command, .shift]
        )
        store.setTranslationShortcut(nil)
        store.setSaveShortcut(saveShortcut)

        let reloadedStore = ShortcutStore(defaults: defaults)
        #expect(reloadedStore.translationShortcut == nil)
        #expect(reloadedStore.saveShortcut == saveShortcut)
    }
}
