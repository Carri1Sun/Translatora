import CoreGraphics
import Foundation

struct TranslationPanelDisplay: Equatable, Sendable {
    let identifier: String
    let visibleFrame: CGRect
}

struct TranslationPanelPlacement: Codable, Equatable, Sendable {
    let screenIdentifier: String
    let offsetX: CGFloat
    let offsetY: CGFloat
    let width: CGFloat
    let height: CGFloat
    let isUserSized: Bool
}

struct TranslationPanelPlacementStore {
    private static let placementKey = "translationPanel.placement"
    private static let edgeInset: CGFloat = 12

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> TranslationPanelPlacement? {
        guard let data = defaults.data(forKey: Self.placementKey) else { return nil }
        return try? JSONDecoder().decode(TranslationPanelPlacement.self, from: data)
    }

    func save(_ placement: TranslationPanelPlacement) {
        guard let data = try? JSONEncoder().encode(placement) else { return }
        defaults.set(data, forKey: Self.placementKey)
    }

    func placement(
        for frame: CGRect,
        on display: TranslationPanelDisplay,
        isUserSized: Bool
    ) -> TranslationPanelPlacement {
        TranslationPanelPlacement(
            screenIdentifier: display.identifier,
            offsetX: frame.minX - display.visibleFrame.minX,
            offsetY: frame.minY - display.visibleFrame.minY,
            width: frame.width,
            height: frame.height,
            isUserSized: isUserSized
        )
    }

    func restoredFrame(
        from placement: TranslationPanelPlacement,
        displays: [TranslationPanelDisplay],
        defaultSize: CGSize
    ) -> CGRect? {
        guard let display = displays.first(where: {
            $0.identifier == placement.screenIdentifier
        }) else {
            return nil
        }

        let size = placement.isUserSized
            ? CGSize(width: placement.width, height: placement.height)
            : defaultSize
        let frame = CGRect(
            x: display.visibleFrame.minX + placement.offsetX,
            y: display.visibleFrame.minY + placement.offsetY,
            width: size.width,
            height: size.height
        )
        if isFullyVisible(frame, across: displays) {
            return frame
        }
        let targetDisplay = nearestDisplay(to: frame, displays: displays) ?? display
        return constrained(frame, to: targetDisplay.visibleFrame)
    }

    func centeredFrame(size: CGSize, on display: TranslationPanelDisplay) -> CGRect {
        let frame = CGRect(
            x: display.visibleFrame.midX - size.width / 2,
            y: display.visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        return constrained(frame, to: display.visibleFrame)
    }

    func constrained(_ frame: CGRect, to visibleFrame: CGRect) -> CGRect {
        let availableWidth = max(1, visibleFrame.width - Self.edgeInset * 2)
        let availableHeight = max(1, visibleFrame.height - Self.edgeInset * 2)
        let size = CGSize(
            width: min(frame.width, availableWidth),
            height: min(frame.height, availableHeight)
        )
        let minX = visibleFrame.minX + Self.edgeInset
        let minY = visibleFrame.minY + Self.edgeInset
        let maxX = visibleFrame.maxX - Self.edgeInset - size.width
        let maxY = visibleFrame.maxY - Self.edgeInset - size.height

        return CGRect(
            x: min(max(frame.minX, minX), maxX),
            y: min(max(frame.minY, minY), maxY),
            width: size.width,
            height: size.height
        )
    }

    func nearestDisplay(
        to frame: CGRect,
        displays: [TranslationPanelDisplay]
    ) -> TranslationPanelDisplay? {
        displays.max { lhs, rhs in
            let lhsIntersection = lhs.visibleFrame.intersection(frame)
            let rhsIntersection = rhs.visibleFrame.intersection(frame)
            let lhsArea = intersectionArea(lhsIntersection)
            let rhsArea = intersectionArea(rhsIntersection)

            if lhsArea != rhsArea {
                return lhsArea < rhsArea
            }

            return squaredDistance(from: frame.center, to: lhs.visibleFrame)
                > squaredDistance(from: frame.center, to: rhs.visibleFrame)
        }
    }

    func isFullyVisible(
        _ frame: CGRect,
        across displays: [TranslationPanelDisplay]
    ) -> Bool {
        guard frame.width > 0, frame.height > 0 else { return false }

        var uniqueVisibleFrames: [CGRect] = []
        for display in displays where !uniqueVisibleFrames.contains(display.visibleFrame) {
            uniqueVisibleFrames.append(display.visibleFrame)
        }

        let coveredArea = uniqueVisibleFrames.reduce(CGFloat.zero) { result, visibleFrame in
            result + intersectionArea(visibleFrame.intersection(frame))
        }
        return coveredArea >= frame.width * frame.height - 1
    }

    private func intersectionArea(_ rect: CGRect) -> CGFloat {
        guard !rect.isNull, !rect.isInfinite else { return 0 }
        return max(0, rect.width) * max(0, rect.height)
    }

    private func squaredDistance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let nearestX = min(max(point.x, rect.minX), rect.maxX)
        let nearestY = min(max(point.y, rect.minY), rect.maxY)
        let dx = point.x - nearestX
        let dy = point.y - nearestY
        return dx * dx + dy * dy
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
