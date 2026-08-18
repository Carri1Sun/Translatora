import Carbon
import Foundation

enum GlobalHotKeyError: LocalizedError {
    case eventHandler(OSStatus)
    case registration(GlobalShortcut, OSStatus)

    var errorDescription: String? {
        switch self {
        case let .eventHandler(status):
            "无法监听全局快捷键（\(status)）"
        case let .registration(shortcut, status):
            "\(shortcut.displayName) 可能已被其他应用占用（\(status)）"
        }
    }
}

@MainActor
final class GlobalHotKeyMonitor {
    private static let signature: OSType = 0x5452_4E53 // TRNS
    private static var nextIdentifier: UInt32 = 1

    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var action: (() -> Void)?
    private var currentShortcut: GlobalShortcut?
    private var registeredIdentifier: UInt32?

    var isStarted: Bool {
        eventHandler != nil
    }

    func start(
        shortcut: GlobalShortcut,
        action: @escaping () -> Void
    ) throws {
        stop()
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return OSStatus(eventNotHandledErr)
                }
                let monitor = Unmanaged<GlobalHotKeyMonitor>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                var hotKeyID = EventHotKeyID(signature: 0, id: 0)
                let parameterStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard parameterStatus == noErr else {
                    return parameterStatus
                }
                guard monitor.handles(hotKeyID) else {
                    return OSStatus(eventNotHandledErr)
                }

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

        do {
            try updateShortcut(shortcut)
        } catch {
            stop()
            throw error
        }
    }

    func updateShortcut(_ shortcut: GlobalShortcut) throws {
        guard currentShortcut != shortcut else { return }

        let identifier = Self.allocateIdentifier()
        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: identifier
        )
        var newHotKey: EventHotKeyRef?
        let registrationStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers.carbonFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKey
        )

        guard registrationStatus == noErr else {
            throw GlobalHotKeyError.registration(shortcut, registrationStatus)
        }

        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        hotKey = newHotKey
        currentShortcut = shortcut
        registeredIdentifier = identifier
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
        currentShortcut = nil
        registeredIdentifier = nil
    }

    private static func allocateIdentifier() -> UInt32 {
        defer { nextIdentifier &+= 1 }
        return nextIdentifier
    }

    private func handles(_ hotKeyID: EventHotKeyID) -> Bool {
        hotKeyID.signature == Self.signature
            && hotKeyID.id == registeredIdentifier
    }

    private func performAction() {
        action?()
    }
}
