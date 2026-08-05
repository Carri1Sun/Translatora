import CoreGraphics
import Foundation
import Testing
@testable import Translatora

@MainActor
struct TranslationPanelPlacementStoreTests {
    @Test
    func restoresPositionRelativeToRememberedDisplayAfterLayoutChanges() throws {
        let store = makeStore()
        let originalDisplay = TranslationPanelDisplay(
            identifier: "external",
            visibleFrame: CGRect(x: 1_440, y: 0, width: 1_920, height: 1_080)
        )
        let placement = store.placement(
            for: CGRect(x: 1_700, y: 220, width: 720, height: 620),
            on: originalDisplay,
            isUserSized: true
        )
        let movedDisplay = TranslationPanelDisplay(
            identifier: "external",
            visibleFrame: CGRect(x: -1_920, y: 120, width: 1_920, height: 1_080)
        )

        let restored = try #require(
            store.restoredFrame(
                from: placement,
                displays: [movedDisplay],
                defaultSize: CGSize(width: 640, height: 350)
            )
        )

        #expect(restored == CGRect(x: -1_660, y: 340, width: 720, height: 620))
    }

    @Test
    func returnsNilWhenRememberedDisplayIsUnavailable() {
        let store = makeStore()
        let placement = TranslationPanelPlacement(
            screenIdentifier: "missing",
            offsetX: 100,
            offsetY: 100,
            width: 700,
            height: 600,
            isUserSized: true
        )

        let restored = store.restoredFrame(
            from: placement,
            displays: [
                TranslationPanelDisplay(
                    identifier: "main",
                    visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
                )
            ],
            defaultSize: CGSize(width: 640, height: 350)
        )

        #expect(restored == nil)
    }

    @Test
    func constrainsAnOffscreenPanelBackInsideNearestDisplay() {
        let store = makeStore()
        let display = TranslationPanelDisplay(
            identifier: "main",
            visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
        )
        let offscreenFrame = CGRect(x: 1_300, y: -200, width: 640, height: 500)

        let targetDisplay = store.nearestDisplay(
            to: offscreenFrame,
            displays: [display]
        )
        let constrained = store.constrained(
            offscreenFrame,
            to: targetDisplay!.visibleFrame
        )

        #expect(constrained == CGRect(x: 788, y: 12, width: 640, height: 500))
        #expect(store.isFullyVisible(constrained, across: [display]))
    }

    @Test
    func allowsAVisiblePanelToSpanAdjacentDisplays() {
        let store = makeStore()
        let displays = [
            TranslationPanelDisplay(
                identifier: "left",
                visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
            ),
            TranslationPanelDisplay(
                identifier: "right",
                visibleFrame: CGRect(x: 1_440, y: 0, width: 1_920, height: 1_080)
            )
        ]
        let spanningFrame = CGRect(x: 1_200, y: 200, width: 640, height: 500)

        #expect(store.isFullyVisible(spanningFrame, across: displays))
    }

    @Test
    func persistsUserResizeMetadata() throws {
        let suiteName = "TranslationPanelPlacementStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = TranslationPanelPlacementStore(defaults: defaults)
        let placement = TranslationPanelPlacement(
            screenIdentifier: "main",
            offsetX: 80,
            offsetY: 60,
            width: 820,
            height: 700,
            isUserSized: true
        )

        store.save(placement)

        #expect(try #require(store.load()) == placement)
    }

    private func makeStore() -> TranslationPanelPlacementStore {
        TranslationPanelPlacementStore(
            defaults: UserDefaults(suiteName: "TranslationPanelPlacementStoreTests.ephemeral")!
        )
    }
}
