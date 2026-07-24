import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
final class SelectedTextReader {
    private let copyTimeoutNanoseconds: UInt64 = 350_000_000
    private let pollIntervalNanoseconds: UInt64 = 10_000_000

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func requestAccessibilityAccess() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func captureSourceProcessIdentifier() -> pid_t? {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication,
              frontmostApplication.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }
        return frontmostApplication.processIdentifier
    }

    func readSelectedText(
        from processIdentifier: pid_t?,
        promptIfNeeded: Bool = true
    ) async -> String? {
        let trusted = promptIfNeeded
            ? requestAccessibilityAccess()
            : isAccessibilityTrusted
        guard trusted else { return nil }

        guard let processIdentifier else { return nil }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        let probeType = NSPasteboard.PasteboardType(
            "com.kaiyisun.translatora.selection-probe"
        )
        let probe = UUID().uuidString

        pasteboard.clearContents()
        pasteboard.setString(probe, forType: probeType)
        let probeChangeCount = pasteboard.changeCount

        guard postCopyShortcut(to: processIdentifier) else {
            snapshot.restore(to: pasteboard)
            return nil
        }

        guard let copiedChangeCount = await waitForPasteboardChange(
            pasteboard,
            after: probeChangeCount
        ) else {
            snapshot.restore(to: pasteboard)
            return nil
        }

        let selectedText = pasteboard.string(forType: .string)
        if pasteboard.changeCount == copiedChangeCount {
            snapshot.restore(to: pasteboard)
        }

        let normalized = selectedText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized?.isEmpty == false ? normalized : nil
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func postCopyShortcut(to processIdentifier: pid_t) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: CGKeyCode(kVK_ANSI_C),
                  keyDown: true
              ),
              let keyUp = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: CGKeyCode(kVK_ANSI_C),
                  keyDown: false
              ) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.postToPid(processIdentifier)
        keyUp.postToPid(processIdentifier)
        return true
    }

    private func waitForPasteboardChange(
        _ pasteboard: NSPasteboard,
        after initialChangeCount: Int
    ) async -> Int? {
        let deadline = DispatchTime.now().uptimeNanoseconds + copyTimeoutNanoseconds

        while DispatchTime.now().uptimeNanoseconds < deadline {
            guard !Task.isCancelled else { return nil }
            if pasteboard.changeCount != initialChangeCount {
                return pasteboard.changeCount
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }

        return pasteboard.changeCount != initialChangeCount
            ? pasteboard.changeCount
            : nil
    }
}

struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard) {
        items = pasteboard.pasteboardItems?.map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        } ?? []
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }

        let pasteboardItems = items.map { representations in
            let item = NSPasteboardItem()
            for (type, data) in representations {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(pasteboardItems)
    }
}
