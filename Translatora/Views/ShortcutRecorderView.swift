import AppKit
import Carbon
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    let shortcut: GlobalShortcut?
    let onChange: (GlobalShortcut) -> Void
    let onValidationError: (String) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.shortcut = shortcut
        button.onChange = onChange
        button.onValidationError = onValidationError
        return button
    }

    func updateNSView(_ nsView: ShortcutRecorderButton, context: Context) {
        nsView.shortcut = shortcut
        nsView.onChange = onChange
        nsView.onValidationError = onValidationError
    }
}

final class ShortcutRecorderButton: NSButton {
    var shortcut: GlobalShortcut? {
        didSet { updateTitle() }
    }
    var onChange: ((GlobalShortcut) -> Void)?
    var onValidationError: ((String) -> Void)?

    private var isRecording = false {
        didSet { updateTitle() }
    }

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if Int(event.keyCode) == kVK_Escape {
            endRecording()
            return
        }

        guard let shortcut = GlobalShortcut(event: event) else {
            NSSound.beep()
            onValidationError?("快捷键需要包含至少一个修饰键和一个普通按键。")
            return
        }

        onChange?(shortcut)
        endRecording()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    private func configure() {
        bezelStyle = .rounded
        controlSize = .large
        focusRingType = .exterior
        target = self
        action = #selector(toggleRecording)
        setButtonType(.momentaryPushIn)
        updateTitle()
    }

    @objc private func toggleRecording() {
        if isRecording {
            endRecording()
        } else {
            isRecording = true
            window?.makeFirstResponder(self)
        }
    }

    private func endRecording() {
        isRecording = false
        window?.makeFirstResponder(nil)
    }

    private func updateTitle() {
        title = isRecording ? "请按新的快捷键…" : (shortcut?.displayName ?? "未设置")
        toolTip = isRecording ? "按 Esc 取消" : "点击后录制快捷键"
    }
}
