import Carbon
import Foundation

enum GlobalHotKeyError: LocalizedError {
    case eventHandler(OSStatus)
    case registration(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .eventHandler(status):
            "无法监听全局快捷键（\(status)）"
        case let .registration(status):
            "⌘⇧T 可能已被其他应用占用（\(status)）"
        }
    }
}

@MainActor
final class GlobalHotKeyMonitor {
    private static let signature: OSType = 0x5452_4E53 // TRNS
    private static let identifier: UInt32 = 1

    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var action: (() -> Void)?

    func start(action: @escaping () -> Void) throws {
        stop()
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let monitor = Unmanaged<GlobalHotKeyMonitor>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                Task { @MainActor in
                    monitor.performAction()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard handlerStatus == noErr else {
            self.action = nil
            throw GlobalHotKeyError.eventHandler(handlerStatus)
        }

        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: Self.identifier
        )
        let registrationStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_T),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )

        guard registrationStatus == noErr else {
            stop()
            throw GlobalHotKeyError.registration(registrationStatus)
        }
    }

    func stop() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        action = nil
    }

    private func performAction() {
        action?()
    }
}
