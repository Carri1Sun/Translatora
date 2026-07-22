import AppKit
import Carbon

struct GlobalShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt8

    static let command = Self(rawValue: 1 << 0)
    static let option = Self(rawValue: 1 << 1)
    static let control = Self(rawValue: 1 << 2)
    static let shift = Self(rawValue: 1 << 3)

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    init(eventFlags: NSEvent.ModifierFlags) {
        var modifiers: Self = []
        if eventFlags.contains(.command) { modifiers.insert(.command) }
        if eventFlags.contains(.option) { modifiers.insert(.option) }
        if eventFlags.contains(.control) { modifiers.insert(.control) }
        if eventFlags.contains(.shift) { modifiers.insert(.shift) }
        self = modifiers
    }

    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }

    var displayName: String {
        var result = ""
        if contains(.command) { result += "⌘" }
        if contains(.option) { result += "⌥" }
        if contains(.control) { result += "⌃" }
        if contains(.shift) { result += "⇧" }
        return result
    }
}

struct GlobalShortcut: Codable, Equatable, Hashable, Sendable {
    let keyCode: UInt32
    let keyDisplayName: String
    let modifiers: GlobalShortcutModifiers

    static let `default` = GlobalShortcut(
        keyCode: UInt32(kVK_ANSI_T),
        keyDisplayName: "T",
        modifiers: [.command, .shift]
    )

    var displayName: String {
        modifiers.displayName + keyDisplayName
    }

    var spacedDisplayName: String {
        let modifierGlyphs = modifiers.displayName.map(String.init)
        return (modifierGlyphs + [keyDisplayName]).joined(separator: " ")
    }

    init(
        keyCode: UInt32,
        keyDisplayName: String,
        modifiers: GlobalShortcutModifiers
    ) {
        self.keyCode = keyCode
        self.keyDisplayName = keyDisplayName
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        let modifiers = GlobalShortcutModifiers(eventFlags: event.modifierFlags)
        guard !modifiers.isEmpty,
              let keyDisplayName = Self.keyDisplayName(for: event) else {
            return nil
        }

        self.init(
            keyCode: UInt32(event.keyCode),
            keyDisplayName: keyDisplayName,
            modifiers: modifiers
        )
    }

    private static func keyDisplayName(for event: NSEvent) -> String? {
        switch Int(event.keyCode) {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "Page Up"
        case kVK_PageDown: return "Page Down"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            break
        }

        guard let characters = event.charactersIgnoringModifiers?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !characters.isEmpty else {
            return nil
        }
        return characters.uppercased()
    }
}
