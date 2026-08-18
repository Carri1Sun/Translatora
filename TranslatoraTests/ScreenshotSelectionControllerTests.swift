import AppKit
import Testing
@testable import Translatora

@MainActor
struct ScreenshotSelectionControllerTests {
    @Test
    func createsSelectionPanelOnTargetScreen() throws {
        let screen = try #require(NSScreen.main)
        let selectionView = ScreenshotSelectionView(
            frame: NSRect(origin: .zero, size: screen.frame.size)
        )
        let panel = ScreenshotSelectionPanel(
            screen: screen,
            selectionView: selectionView
        )
        defer { panel.orderOut(nil) }

        #expect(panel.frame == screen.frame)
        #expect(panel.styleMask.contains(.borderless))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(!panel.hidesOnDeactivate)
        #expect(!panel.becomesKeyOnlyIfNeeded)
        #expect(panel.contentView === selectionView)
    }
}
