import AppKit
import Combine
import SwiftUI

@MainActor
final class TranslationPanelController: NSObject, NSWindowDelegate {
    private let panel: TranslationPanel
    private let viewModel: TranslationPanelViewModel
    private let shortcutStore: ShortcutStore
    private let selectedTextReader: SelectedTextReader
    private var phaseCancellable: AnyCancellable?
    private var appearanceCancellable: AnyCancellable?
    private var selectionReadTask: Task<Void, Never>?
    private var selectionReadGeneration = 0

    init(
        translationService: TranslationService,
        dictionaryStore: DictionaryStore,
        appearanceStore: AppearanceStore,
        shortcutStore: ShortcutStore,
        selectedTextReader: SelectedTextReader
    ) {
        viewModel = TranslationPanelViewModel(
            translationService: translationService,
            dictionaryStore: dictionaryStore
        )
        self.shortcutStore = shortcutStore
        self.selectedTextReader = selectedTextReader
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
        selectionReadGeneration += 1
        let generation = selectionReadGeneration

        selectionReadTask = Task { [weak self] in
            guard let self else { return }
            let selectedText = await selectedTextReader.readSelectedText(promptIfNeeded: true)
            guard !Task.isCancelled,
                  selectionReadGeneration == generation else { return }

            selectionReadTask = nil
            viewModel.prepare(selectedText: selectedText)
            resize(for: .idle, animated: false)
            panel.center()
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

        let rootView = TranslationPanelView(
            viewModel: viewModel,
            appearanceStore: appearanceStore,
            shortcutStore: shortcutStore,
            onClose: { [weak self] in self?.close() }
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
}

private final class TranslationPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
