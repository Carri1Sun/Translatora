import AppKit
import ApplicationServices

@MainActor
final class SelectedTextReader {
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

    func readSelectedText(promptIfNeeded: Bool = true) -> String? {
        let trusted = promptIfNeeded
            ? requestAccessibilityAccess()
            : isAccessibilityTrusted
        guard trusted else { return nil }

        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication,
              frontmostApplication.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }

        let applicationElement = AXUIElementCreateApplication(frontmostApplication.processIdentifier)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
        let focusedValue else {
            return nil
        }

        let focusedElement = focusedValue as! AXUIElement
        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        ) == .success,
        let selectedText = selectedValue as? String else {
            return nil
        }

        let normalized = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
