import AppKit
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppTheme {
    static let accent = Color(red: 149 / 255, green: 236 / 255, blue: 104 / 255)
    static let accentDeep = Color(red: 54 / 255, green: 135 / 255, blue: 50 / 255)
    static let accentSoft = Color(red: 214 / 255, green: 250 / 255, blue: 196 / 255)
    static let ink = Color(red: 19 / 255, green: 31 / 255, blue: 24 / 255)
    static let windowSurface = Color(nsColor: .windowBackgroundColor)
    static let raisedSurface = Color(nsColor: .controlBackgroundColor)

    static func panelTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.075, green: 0.085, blue: 0.078).opacity(0.82)
            : Color(red: 0.975, green: 0.982, blue: 0.972).opacity(0.86)
    }
}

struct AppButtonStyle: ButtonStyle {
    var isProminent = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(isProminent ? AppTheme.ink : Color.primary)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                isProminent
                    ? AppTheme.accent.opacity(configuration.isPressed ? 0.78 : 1)
                    : controlFill(configuration.isPressed),
                in: .rect(cornerRadius: 9)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        isProminent
                            ? AppTheme.accentDeep.opacity(0.24)
                            : Color.primary.opacity(0.11),
                        lineWidth: 1
                    )
            }
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func controlFill(_ isPressed: Bool) -> Color {
        let baseOpacity = colorScheme == .dark ? 0.085 : 0.055
        return Color.primary.opacity(isPressed ? baseOpacity + 0.055 : baseOpacity)
    }
}

struct AppIconButtonStyle: ButtonStyle {
    var scalesWhenPressed = true

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 32, height: 32)
            .contentShape(.rect(cornerRadius: 9))
            .background(
                Color.primary.opacity(
                    configuration.isPressed
                        ? pressedOpacity
                        : restingOpacity
                ),
                in: .rect(cornerRadius: 9)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.42)
            .scaleEffect(configuration.isPressed && scalesWhenPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var restingOpacity: Double {
        colorScheme == .dark ? 0.08 : 0.045
    }

    private var pressedOpacity: Double {
        colorScheme == .dark ? 0.16 : 0.1
    }
}

struct AppAccentCircleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.ink)
            .padding(7)
            .background(
                AppTheme.accent.opacity(configuration.isPressed ? 0.78 : 1),
                in: .circle
            )
            .overlay {
                Circle()
                    .stroke(AppTheme.accentDeep.opacity(0.25), lineWidth: 1)
            }
            .contentShape(.circle)
            .opacity(isEnabled ? 1 : 0.38)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppAccentCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                AppTheme.accent.opacity(configuration.isPressed ? 0.78 : 1),
                in: .capsule
            )
            .overlay {
                Capsule()
                    .stroke(AppTheme.accentDeep.opacity(0.25), lineWidth: 1)
            }
            .contentShape(.capsule)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A traditional macOS background blur without Liquid Glass refraction or highlights.
struct GaussianBlurBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: NSVisualEffectView) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = false
    }
}
