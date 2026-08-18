import AppKit
import Combine
import SwiftUI

@MainActor
final class TranslationPanelController: NSObject, NSWindowDelegate {
    private static let defaultSize = NSSize(width: 640, height: 350)

    private let panel: TranslationPanel
    private let viewModel: TranslationPanelViewModel
    private let shortcutStore: ShortcutStore
    private let selectedTextReader: SelectedTextReader
    private let placementStore: TranslationPanelPlacementStore
    private let onViewDictionaryEntry: (UUID) -> Void
    private let savedToastController = SavedEntryToastController()
    private var phaseCancellable: AnyCancellable?
    private var appearanceCancellable: AnyCancellable?
    private var phaseUpdateTask: Task<Void, Never>?
    private var selectionReadTask: Task<Void, Never>?
    private var moveSettlementTask: Task<Void, Never>?
    private var selectionReadGeneration = 0
    private var isApplyingFrame = false
    private var isUserSized = false
    private var isResizeEnabled = false

    init(
        translationService: TranslationService,
        dictionaryStore: DictionaryStore,
        appearanceStore: AppearanceStore,
        shortcutStore: ShortcutStore,
        selectedTextReader: SelectedTextReader,
        pronunciationService: PronunciationService,
        onViewDictionaryEntry: @escaping (UUID) -> Void,
        placementStore: TranslationPanelPlacementStore? = nil
    ) {
        viewModel = TranslationPanelViewModel(
            translationService: translationService,
            dictionaryStore: dictionaryStore
        )
        self.shortcutStore = shortcutStore
        self.selectedTextReader = selectedTextReader
        self.onViewDictionaryEntry = onViewDictionaryEntry
        self.placementStore = placementStore ?? TranslationPanelPlacementStore()
        panel = TranslationPanel(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .fullSizeContentView,
                .nonactivatingPanel
            ],
            backing: .buffered,
            defer: false
        )
        super.init()

        configurePanel(
            appearanceStore: appearanceStore,
            pronunciationService: pronunciationService
        )
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
        restorePlacement()
        updateResizable(for: .idle)
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

    func show(screenshotImageData: Data) {
        savedToastController.dismiss()
        selectionReadGeneration += 1
        selectionReadTask?.cancel()
        selectionReadTask = nil

        viewModel.prepare(screenshotImageData: screenshotImageData)
        restorePlacement()
        updateResizable(for: .idle)
        panel.makeKeyAndOrderFront(nil)

        Task { [weak self] in
            await Task.yield()
            self?.viewModel.translateAutomaticallyIfNeeded()
        }
    }

    func close() {
        if panel.isVisible {
            constrainAndPersist(animate: false)
        }
        moveSettlementTask?.cancel()
        moveSettlementTask = nil
        selectionReadGeneration += 1
        selectionReadTask?.cancel()
        selectionReadTask = nil
        panel.orderOut(nil)
        viewModel.reset()
    }

    func windowWillClose(_ notification: Notification) {
        constrainAndPersist(animate: false)
        viewModel.reset()
    }

    func windowDidMove(_ notification: Notification) {
        guard panel.isVisible, !isApplyingFrame, !panel.inLiveResize else { return }
        scheduleMoveSettlement()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard isResizeEnabled, !isApplyingFrame else { return }
        isUserSized = true
        constrainAndPersist(animate: true)
    }

    func windowWillResize(
        _ sender: NSWindow,
        to frameSize: NSSize
    ) -> NSSize {
        isResizeEnabled ? frameSize : sender.frame.size
    }

    func windowDidChangeScreen(_ notification: Notification) {
        updateResizeLimits()
        guard panel.isVisible, !isApplyingFrame else { return }
        scheduleMoveSettlement()
    }

    private func configurePanel(
        appearanceStore: AppearanceStore,
        pronunciationService: PronunciationService
    ) {
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
        panel.minSize = NSSize(width: 520, height: 350)
        updateResizeLimits()
        panel.onKeyDown = { [weak self] event in
            self?.handleSaveShortcut(event) ?? false
        }

        let rootView = TranslationPanelView(
            viewModel: viewModel,
            appearanceStore: appearanceStore,
            shortcutStore: shortcutStore,
            pronunciationService: pronunciationService,
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
                self?.phaseUpdateTask?.cancel()
                self?.phaseUpdateTask = Task { [weak self] in
                    await Task.yield()
                    guard !Task.isCancelled,
                          let self,
                          self.viewModel.phase == phase else { return }
                    self.updateResizable(for: phase)
                    self.resize(for: phase, animated: true)
                }
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
        if isUserSized {
            constrainAndPersist(animate: false)
            return
        }

        let preferredHeight: CGFloat
        switch phase {
        case .idle:
            preferredHeight = viewModel.isScreenshotInput ? 520 : 350
        case .loading, .failure:
            preferredHeight = viewModel.isScreenshotInput ? 610 : 430
        case let .result(result):
            if viewModel.isScreenshotInput {
                preferredHeight = 620
            } else {
                preferredHeight = result.examples.isEmpty ? 500 : 650
            }
        }

        let availableHeight = panel.screen?.visibleFrame.height ?? 760
        let height = min(preferredHeight, availableHeight - 40)
        let oldFrame = panel.frame
        let targetFrame = NSRect(
            x: oldFrame.minX,
            y: oldFrame.maxY - height,
            width: Self.defaultSize.width,
            height: height
        )

        applyFrame(targetFrame, animate: animated && panel.isVisible)
    }

    private func restorePlacement() {
        let displays = availableDisplays
        guard let defaultDisplay = defaultDisplay(from: displays) else {
            applyFrame(NSRect(origin: .zero, size: Self.defaultSize), animate: false)
            panel.center()
            return
        }

        guard let placement = placementStore.load() else {
            isUserSized = false
            applyFrame(
                placementStore.centeredFrame(size: Self.defaultSize, on: defaultDisplay),
                animate: false
            )
            return
        }

        isUserSized = placement.isUserSized
        if let restoredFrame = placementStore.restoredFrame(
            from: placement,
            displays: displays,
            defaultSize: Self.defaultSize
        ) {
            applyFrame(restoredFrame, animate: false)
            persistCurrentPlacement(on: placementStore.nearestDisplay(
                to: restoredFrame,
                displays: displays
            ))
            return
        }

        let restoredSize = placement.isUserSized
            ? NSSize(width: placement.width, height: placement.height)
            : Self.defaultSize
        let centeredFrame = placementStore.centeredFrame(
            size: restoredSize,
            on: defaultDisplay
        )
        applyFrame(centeredFrame, animate: false)
        persistCurrentPlacement(on: defaultDisplay)
    }

    private func updateResizable(for phase: TranslationPhase) {
        isResizeEnabled = phase.allowsPanelResize
        panel.standardWindowButton(.zoomButton)?.isEnabled = isResizeEnabled
        updateResizeLimits()
    }

    private func updateResizeLimits() {
        let visibleFrame = panel.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1_200, height: 800)
        panel.maxSize = NSSize(
            width: max(panel.minSize.width, visibleFrame.width - 24),
            height: max(panel.minSize.height, visibleFrame.height - 24)
        )
    }

    private func scheduleMoveSettlement() {
        moveSettlementTask?.cancel()
        moveSettlementTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            guard NSEvent.pressedMouseButtons & 1 == 0 else {
                self?.scheduleMoveSettlement()
                return
            }
            guard self?.panel.isVisible == true else { return }
            self?.constrainAndPersist(animate: true)
        }
    }

    private func constrainAndPersist(animate: Bool) {
        let displays = availableDisplays
        guard let targetDisplay = placementStore.nearestDisplay(
            to: panel.frame,
            displays: displays
        ) else { return }

        let targetFrame: NSRect
        if placementStore.isFullyVisible(panel.frame, across: displays) {
            targetFrame = panel.frame
        } else {
            targetFrame = placementStore.constrained(
                panel.frame,
                to: targetDisplay.visibleFrame
            )
        }

        if !panel.frame.equalTo(targetFrame) {
            applyFrame(targetFrame, animate: animate && panel.isVisible)
        }
        updateResizeLimits()
        persistCurrentPlacement(on: targetDisplay)
    }

    private func persistCurrentPlacement(on display: TranslationPanelDisplay?) {
        guard let display else { return }
        placementStore.save(
            placementStore.placement(
                for: panel.frame,
                on: display,
                isUserSized: isUserSized
            )
        )
    }

    private func applyFrame(_ frame: NSRect, animate: Bool) {
        moveSettlementTask?.cancel()
        moveSettlementTask = nil
        isApplyingFrame = true
        defer { isApplyingFrame = false }

        if animate {
            panel.setFrame(frame, display: true, animate: true)
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private var availableDisplays: [TranslationPanelDisplay] {
        NSScreen.screens.map { screen in
            TranslationPanelDisplay(
                identifier: screenIdentifier(screen),
                visibleFrame: screen.visibleFrame
            )
        }
    }

    private func defaultDisplay(
        from displays: [TranslationPanelDisplay]
    ) -> TranslationPanelDisplay? {
        if let screen = NSScreen.main {
            let identifier = screenIdentifier(screen)
            return displays.first(where: { $0.identifier == identifier })
        }
        return displays.first
    }

    private func screenIdentifier(_ screen: NSScreen) -> String {
        if let number = screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber {
            return number.stringValue
        }
        return "\(screen.localizedName)-\(screen.frame.debugDescription)"
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
        constrainAndPersist(animate: false)
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
