import AppKit
import ScreenCaptureKit
import SwiftUI

enum ScreenshotCaptureError: LocalizedError {
    case permissionRequired
    case emptySelection
    case unableToEncode
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            "需要屏幕录制权限才能使用截图翻译，请在系统设置中授权后重试。"
        case .emptySelection:
            "请选择一个有效的截图区域。"
        case .unableToEncode:
            "无法处理所选截图。"
        case let .captureFailed(message):
            "截图失败：\(message)"
        }
    }
}

@MainActor
final class ScreenshotSelectionController {
    private var panels: [ScreenshotSelectionPanel] = []
    private var captureTask: Task<Void, Never>?
    private var onCaptured: ((Data) -> Void)?
    private var onError: ((String) -> Void)?

    var isSelecting: Bool {
        !panels.isEmpty
    }

    func start(
        onCaptured: @escaping (Data) -> Void,
        onError: @escaping (String) -> Void
    ) {
        cancel()
        self.onCaptured = onCaptured
        self.onError = onError

        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            finishWithError(ScreenshotCaptureError.permissionRequired)
            return
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            finishWithError(ScreenshotCaptureError.captureFailed("没有可用的显示器"))
            return
        }

        for screen in screens {
            let selectionView = ScreenshotSelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
            selectionView.onBeginSelection = { [weak self, weak selectionView] in
                self?.panels.forEach { panel in
                    guard panel.selectionView !== selectionView else { return }
                    panel.selectionView.resetSelection()
                }
            }
            selectionView.onConfirm = { [weak self, weak screen] rect in
                guard let screen else { return }
                self?.capture(selection: rect, on: screen)
            }
            selectionView.onCancel = { [weak self] in
                self?.cancel()
            }

            let panel = ScreenshotSelectionPanel(screen: screen, selectionView: selectionView)
            panels.append(panel)
            panel.orderFrontRegardless()
        }

        let mouseLocation = NSEvent.mouseLocation
        let activePanel = panels.first { $0.screen?.frame.contains(mouseLocation) == true }
            ?? panels.first
        activePanel?.makeKeyAndOrderFront(nil)
        activePanel?.selectionView.window?.makeFirstResponder(activePanel?.selectionView)
    }

    func cancel() {
        captureTask?.cancel()
        captureTask = nil
        dismissPanels()
        onCaptured = nil
        onError = nil
    }

    private func capture(selection: NSRect, on screen: NSScreen) {
        guard selection.width >= 4, selection.height >= 4 else {
            finishWithError(ScreenshotCaptureError.emptySelection)
            return
        }

        let captureRect = Self.screenCaptureRect(for: selection, on: screen)
        dismissPanels()

        captureTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(120))
                try Task.checkCancellation()
                let image = try await SCScreenshotManager.captureImage(in: captureRect)
                try Task.checkCancellation()

                let bitmap = NSBitmapImageRep(cgImage: image)
                guard let data = bitmap.representation(using: .png, properties: [:]) else {
                    throw ScreenshotCaptureError.unableToEncode
                }

                let completion = self?.onCaptured
                self?.onCaptured = nil
                self?.onError = nil
                self?.captureTask = nil
                completion?(data)
            } catch is CancellationError {
                return
            } catch let error as ScreenshotCaptureError {
                self?.finishWithError(error)
            } catch {
                self?.finishWithError(
                    ScreenshotCaptureError.captureFailed(error.localizedDescription)
                )
            }
        }
    }

    private static func screenCaptureRect(for selection: NSRect, on screen: NSScreen) -> CGRect {
        let displayID = (screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
        let displayBounds = CGDisplayBounds(displayID)

        return CGRect(
            x: displayBounds.minX + selection.minX,
            y: displayBounds.minY + screen.frame.height - selection.maxY,
            width: selection.width,
            height: selection.height
        ).integral
    }

    private func dismissPanels() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }

    private func finishWithError(_ error: Error) {
        dismissPanels()
        captureTask = nil
        let errorHandler = onError
        onCaptured = nil
        onError = nil
        errorHandler?(error.localizedDescription)
    }
}

final class ScreenshotSelectionPanel: NSPanel {
    let selectionView: ScreenshotSelectionView

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(screen: NSScreen, selectionView: ScreenshotSelectionView) {
        self.selectionView = selectionView
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        contentView = selectionView
    }
}

final class ScreenshotSelectionView: NSView {
    var onBeginSelection: (() -> Void)?
    var onConfirm: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private var dragOrigin: NSPoint?
    private(set) var selectionRect = NSRect.zero
    private var isSelectionComplete = false

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let overlayPath = NSBezierPath(rect: bounds)
        if !selectionRect.isEmpty {
            overlayPath.appendRect(selectionRect)
            overlayPath.windingRule = .evenOdd
        }
        NSColor.black.withAlphaComponent(0.48).setFill()
        overlayPath.fill()

        if !selectionRect.isEmpty {
            drawSelection()
        } else {
            drawInstruction()
        }

        if isSelectionComplete {
            drawToolbar()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if isSelectionComplete {
            if cancelButtonRect.contains(point) {
                onCancel?()
                return
            }
            if confirmButtonRect.contains(point) {
                onConfirm?(selectionRect)
                return
            }
        }

        onBeginSelection?()
        dragOrigin = constrained(point)
        selectionRect = NSRect(origin: constrained(point), size: .zero)
        isSelectionComplete = false
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragOrigin else { return }
        selectionRect = normalizedRect(from: dragOrigin, to: constrained(
            convert(event.locationInWindow, from: nil)
        ))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let dragOrigin else { return }
        self.dragOrigin = nil
        selectionRect = normalizedRect(from: dragOrigin, to: constrained(
            convert(event.locationInWindow, from: nil)
        ))
        if selectionRect.width < 4 || selectionRect.height < 4 {
            resetSelection()
            NSSound.beep()
            return
        }
        isSelectionComplete = true
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            if isSelectionComplete {
                onConfirm?(selectionRect)
            } else {
                super.keyDown(with: event)
            }
        case 53:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
        if isSelectionComplete {
            addCursorRect(cancelButtonRect, cursor: .pointingHand)
            addCursorRect(confirmButtonRect, cursor: .pointingHand)
        }
    }

    func resetSelection() {
        dragOrigin = nil
        selectionRect = .zero
        isSelectionComplete = false
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    private func drawSelection() {
        let borderPath = NSBezierPath(rect: selectionRect.insetBy(dx: 0.5, dy: 0.5))
        borderPath.lineWidth = 2
        NSColor.white.setStroke()
        borderPath.stroke()

        let handleSize: CGFloat = 7
        for point in selectionHandlePoints {
            let rect = NSRect(
                x: point.x - handleSize / 2,
                y: point.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            NSColor.white.setFill()
            NSBezierPath(ovalIn: rect).fill()
        }

        let sizeText = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
        drawPill(
            sizeText,
            centeredAt: NSPoint(x: selectionRect.midX, y: selectionRect.maxY + 18),
            font: .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        )
    }

    private func drawInstruction() {
        drawPill(
            "拖动选择截图区域  ·  Esc 取消",
            centeredAt: NSPoint(x: bounds.midX, y: bounds.midY),
            font: .systemFont(ofSize: 14, weight: .medium)
        )
    }

    private func drawToolbar() {
        let toolbar = toolbarRect
        NSColor(calibratedWhite: 0.1, alpha: 0.94).setFill()
        NSBezierPath(roundedRect: toolbar, xRadius: 11, yRadius: 11).fill()

        drawButtonTitle("取消", in: cancelButtonRect, color: .white.withAlphaComponent(0.78))

        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: confirmButtonRect, xRadius: 8, yRadius: 8).fill()
        drawButtonTitle("翻译", in: confirmButtonRect, color: .white)
    }

    private func drawButtonTitle(_ title: String, in rect: NSRect, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: color
        ]
        let size = title.size(withAttributes: attributes)
        title.draw(
            at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
            withAttributes: attributes
        )
    }

    private func drawPill(_ text: String, centeredAt center: NSPoint, font: NSFont) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attributes)
        let size = NSSize(width: textSize.width + 22, height: textSize.height + 12)
        var origin = NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        origin.x = min(max(origin.x, bounds.minX + 8), bounds.maxX - size.width - 8)
        origin.y = min(max(origin.y, bounds.minY + 8), bounds.maxY - size.height - 8)
        let background = NSRect(origin: origin, size: size)

        NSColor(calibratedWhite: 0.08, alpha: 0.88).setFill()
        NSBezierPath(roundedRect: background, xRadius: size.height / 2, yRadius: size.height / 2).fill()
        text.draw(
            at: NSPoint(x: background.midX - textSize.width / 2, y: background.midY - textSize.height / 2),
            withAttributes: attributes
        )
    }

    private var toolbarRect: NSRect {
        let size = NSSize(width: 150, height: 44)
        let belowY = selectionRect.minY - size.height - 12
        let y = belowY >= bounds.minY + 8
            ? belowY
            : min(selectionRect.maxY + 12, bounds.maxY - size.height - 8)
        let x = min(
            max(selectionRect.maxX - size.width, bounds.minX + 8),
            bounds.maxX - size.width - 8
        )
        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }

    private var cancelButtonRect: NSRect {
        NSRect(x: toolbarRect.minX + 8, y: toolbarRect.minY + 6, width: 59, height: 32)
    }

    private var confirmButtonRect: NSRect {
        NSRect(x: toolbarRect.maxX - 75, y: toolbarRect.minY + 6, width: 67, height: 32)
    }

    private var selectionHandlePoints: [NSPoint] {
        [
            NSPoint(x: selectionRect.minX, y: selectionRect.minY),
            NSPoint(x: selectionRect.midX, y: selectionRect.minY),
            NSPoint(x: selectionRect.maxX, y: selectionRect.minY),
            NSPoint(x: selectionRect.minX, y: selectionRect.midY),
            NSPoint(x: selectionRect.maxX, y: selectionRect.midY),
            NSPoint(x: selectionRect.minX, y: selectionRect.maxY),
            NSPoint(x: selectionRect.midX, y: selectionRect.maxY),
            NSPoint(x: selectionRect.maxX, y: selectionRect.maxY)
        ]
    }

    private func normalizedRect(from start: NSPoint, to end: NSPoint) -> NSRect {
        NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        ).intersection(bounds)
    }

    private func constrained(_ point: NSPoint) -> NSPoint {
        NSPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }
}

@MainActor
final class CenterToastController {
    private var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?

    func show(message: String, systemImage: String = "exclamationmark.triangle.fill") {
        dismiss()

        let size = NSSize(width: 380, height: 76)
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
        let frame = screen.map {
            NSRect(
                x: $0.frame.midX - size.width / 2,
                y: $0.frame.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
        } ?? NSRect(origin: .zero, size: size)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentViewController = NSHostingController(
            rootView: CenterToastView(message: message, systemImage: systemImage)
        )
        panel.orderFrontRegardless()
        self.panel = panel

        dismissalTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.8))
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

private struct CenterToastView: View {
    let message: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.orange)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.12), lineWidth: 1)
        }
    }
}
