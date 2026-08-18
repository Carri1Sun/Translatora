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
        #expect(store.screenshotShortcut == .screenshotDefault)
        #expect(store.saveShortcut == nil)

        let saveShortcut = GlobalShortcut(
            keyCode: UInt32(kVK_ANSI_S),
            keyDisplayName: "S",
            modifiers: [.command, .shift]
        )
        store.setTranslationShortcut(nil)
        store.setScreenshotShortcut(nil)
        store.setSaveShortcut(saveShortcut)

        let reloadedStore = ShortcutStore(defaults: defaults)
        #expect(reloadedStore.translationShortcut == nil)
        #expect(reloadedStore.screenshotShortcut == nil)
        #expect(reloadedStore.saveShortcut == saveShortcut)
    }

    @Test
    func addsScreenshotDefaultWhenLoadingPreviousConfiguration() throws {
        let suiteName = "TranslatoraTests.Shortcuts.Legacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let legacyConfiguration = LegacyShortcutConfiguration(
            translationShortcut: .default,
            saveShortcut: nil
        )
        defaults.set(
            try JSONEncoder().encode(legacyConfiguration),
            forKey: "shortcuts.configuration.v2"
        )

        let store = ShortcutStore(defaults: defaults)

        #expect(store.translationShortcut == .default)
        #expect(store.screenshotShortcut == .screenshotDefault)
    }
}

private struct LegacyShortcutConfiguration: Encodable {
    let translationShortcut: GlobalShortcut?
    let saveShortcut: GlobalShortcut?
}
