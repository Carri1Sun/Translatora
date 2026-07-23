import AppKit
import Testing
@testable import Translatora

@MainActor
struct MainWindowControllerTests {
    @Test
    func closeHidesWindowAndShowRestoresIt() {
        let controller = MainWindowController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        defer { window.orderOut(nil) }

        controller.attach(window)
        window.orderFront(nil)
        #expect(window.isVisible)

        window.performClose(nil)
        #expect(!window.isVisible)

        #expect(controller.show())
        #expect(window.isVisible)
    }
}
