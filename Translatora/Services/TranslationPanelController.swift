import AppKit
import Combine
import SwiftUI

@MainActor
final class TranslationPanelController: NSObject, NSWindowDelegate {
    private let panel: TranslationPanel
    private let viewModel: TranslationPanelViewModel
    private let shortcutStore: ShortcutStore
    private let selectedTextReader: SelectedTextReader
    private let onViewDictionaryEntry: (UUID) -> Void
    private let savedToastController = SavedEntryToastController()
    private var phaseCancellable: AnyCancellable?
    private var appearanceCancellable: AnyCancellable?
    private var selectionReadTask: Task<Void, Never>?
    private var selectionReadGeneration = 0

    init(
        translationService: TranslationService,
        dictionaryStore: DictionaryStore,
        appearanceStore: AppearanceStore,
        shortcutStore: ShortcutStore,
        selectedTextReader: SelectedTextReader,
        onViewDictionaryEntry: @escaping (UUID) -> Void
    ) {
        viewModel = TranslationPanelViewModel(
            translationService: translationService,
            dictionaryStore: dictionaryStore
        )
        self.shortcutStore = shortcutStore
        self.selectedTextReader = selectedTextReader
        self.onViewDictionaryEntry = onViewDictionaryEntry
        panel = TranslationPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 350),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        configurePanel(appearanceStore: appearanceStore)
        observePhase()
        observeAppearance(appearanceStore)
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func toggle() {
        if panel.isVisible {
            close()
        } else if selectionReadTask != nil {
            selectionReadGeneration += 1
            selectionReadTask?.cancel()
            selectionReadTask = nil
        } else {
            show()
        }
    }

    func show() {
        guard selectionReadTask == nil else { return }
        savedToastController.dismiss()
        selectionReadGeneration += 1
        let generation = selectionReadGeneration
        let sourceProcessIdentifier = selectedTextReader.captureSourceProcessIdentifier()

        viewModel.prepare(selectedText: nil)
        resize(for: .idle, animated: false)
        panel.center()
        panel.orderFrontRegardless()

        selectionReadTask = Task { [weak self] in
            guard let self else { return }
            let selectedText = await selectedTextReader.readSelectedText(
                from: sourceProcessIdentifier,
                promptIfNeeded: true
            )
            guard !Task.isCancelled,
                  selectionReadGeneration == generation else { return }

            selectionReadTask = nil
            viewModel.prepare(selectedText: selectedText)
            panel.makeKeyAndOrderFront(nil)

            await Task.yield()
            viewModel.translateAutomaticallyIfNeeded()
        }
    }

    func close() {
        selectionReadGeneration += 1
        selectionReadTask?.cancel()
        selectionReadTask = nil
        panel.orderOut(nil)
        viewModel.reset()
    }

    func windowWillClose(_ notification: Notification) {
        viewModel.reset()
    }

    private func configurePanel(appearanceStore: AppearanceStore) {
        panel.delegate = self
        panel.title = "翻译浮窗"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.minSize = NSSize(width: 640, height: 350)
        panel.maxSize = NSSize(width: 640, height: 760)
        panel.onKeyDown = { [weak self] event in
            self?.handleSaveShortcut(event) ?? false
        }

        let rootView = TranslationPanelView(
            viewModel: viewModel,
            appearanceStore: appearanceStore,
            shortcutStore: shortcutStore,
            onClose: { [weak self] in self?.close() },
            onSaved: { [weak self] entry in self?.handleSavedEntry(entry) }
        )
        panel.contentViewController = NSHostingController(rootView: rootView)
    }

    private func observePhase() {
        phaseCancellable = viewModel.$phase
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] phase in
                self?.resize(for: phase, animated: true)
            }
    }

    private func observeAppearance(_ appearanceStore: AppearanceStore) {
        appearanceCancellable = appearanceStore.$appearance
            .removeDuplicates()
            .sink { [weak self] appearance in
                switch appearance {
                case .system:
                    self?.panel.appearance = nil
                case .light:
                    self?.panel.appearance = NSAppearance(named: .aqua)
                case .dark:
                    self?.panel.appearance = NSAppearance(named: .darkAqua)
                }
            }
    }

    private func resize(for phase: TranslationPhase, animated: Bool) {
        let preferredHeight: CGFloat
        switch phase {
        case .idle: preferredHeight = 350
        case .loading, .failure: preferredHeight = 430
        case let .result(result):
            preferredHeight = result.examples.isEmpty ? 500 : 650
        }

        let availableHeight = panel.screen?.visibleFrame.height ?? 760
        let height = min(preferredHeight, availableHeight - 40)
        let oldFrame = panel.frame
        let targetFrame = NSRect(
            x: oldFrame.minX,
            y: oldFrame.maxY - height,
            width: 640,
            height: height
        )

        guard animated, panel.isVisible else {
            panel.setFrame(targetFrame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    private func handleSaveShortcut(_ event: NSEvent) -> Bool {
        guard let shortcut = shortcutStore.saveShortcut,
              shortcut.matches(event) else {
            return false
        }

        guard let entry = viewModel.saveResult() else {
            NSSound.beep()
            return true
        }
        handleSavedEntry(entry)
        return true
    }

    private func handleSavedEntry(_ entry: DictionaryEntry) {
        let anchorFrame = panel.frame
        panel.orderOut(nil)
        viewModel.reset()
        savedToastController.show(near: anchorFrame, appearance: panel.appearance) { [weak self] in
            self?.onViewDictionaryEntry(entry.id)
        }
    }
}

private final class TranslationPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, onKeyDown?(event) == true {
            return
        }
        super.sendEvent(event)
    }
}

@MainActor
private final class SavedEntryToastController {
    private var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?

    func show(
        near anchorFrame: NSRect,
        appearance: NSAppearance?,
        onView: @escaping () -> Void
    ) {
        dismiss()

        let size = NSSize(width: 200, height: 58)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.appearance = appearance
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentViewController = NSHostingController(
            rootView: SavedEntryToastView { [weak self] in
                self?.dismiss()
                onView()
            }
        )

        let visibleFrame = NSScreen.screens
            .first(where: { $0.frame.intersects(anchorFrame) })?
            .visibleFrame ?? NSScreen.main?.visibleFrame ?? anchorFrame
        let origin = NSPoint(
            x: min(
                max(anchorFrame.maxX - size.width, visibleFrame.minX + 12),
                visibleFrame.maxX - size.width - 12
            ),
            y: min(
                max(anchorFrame.maxY - size.height - 12, visibleFrame.minY + 12),
                visibleFrame.maxY - size.height - 12
            )
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        self.panel = panel

        dismissalTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissalTask?.cancel()
        dismissalTask = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct SavedEntryToastView: View {
    let onView: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onView) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.accentDeep)

                Text("已保存到词典")
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(width: 200, height: 58)
            .contentShape(.rect)
            .background {
                ZStack {
                    GaussianBlurBackground(
                        material: .hudWindow,
                        blendingMode: .behindWindow
                    )
                    AppTheme.panelTint(for: colorScheme)
                }
                .clipShape(.rect(cornerRadius: 16))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.primary.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
