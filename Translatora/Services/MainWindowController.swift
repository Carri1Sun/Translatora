import AppKit

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    private weak var window: NSWindow?
    private weak var forwardedDelegate: (any NSWindowDelegate)?

    func attach(_ window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        forwardedDelegate = window.delegate
        window.delegate = self
        window.isReleasedWhenClosed = false
    }

    @discardableResult
    func show() -> Bool {
        guard let window else { return false }

        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector)
            || forwardedDelegate?.responds(to: selector) == true
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        if forwardedDelegate?.responds(to: selector) == true {
            return forwardedDelegate
        }
        return super.forwardingTarget(for: selector)
    }
}
