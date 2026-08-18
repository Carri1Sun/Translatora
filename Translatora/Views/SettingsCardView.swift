import SwiftUI

struct SettingsCardView: View {
    private enum Page: String, CaseIterable, Identifiable {
        case general
        case apiKeys
        case providers

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general:
                "通用设置"
            case .apiKeys:
                "API Key"
            case .providers:
                "Provider"
            }
        }

        var icon: String {
            switch self {
            case .general:
                "gearshape"
            case .apiKeys:
                "key"
            case .providers:
                "cpu"
            }
        }
    }

    @ObservedObject var configurationStore: ConfigurationStore
    let languageModelProvider: LanguageModelProviderRouter
    let ttsProvider: TTSProviderRouter
    let pronunciationCache: SpeechAudioCache
    @ObservedObject var appearanceStore: AppearanceStore
    @ObservedObject var menuBarStore: MenuBarStore
    @ObservedObject var shortcutStore: ShortcutStore
    let shortcutErrorMessage: String?
    let updateTranslationShortcut: (GlobalShortcut?) -> Bool
    let updateScreenshotShortcut: (GlobalShortcut?) -> Bool
    let updateSaveShortcut: (GlobalShortcut?) -> Bool
    let selectedTextReader: SelectedTextReader
    let onClose: () -> Void

    @State private var selectedPage = Page.general

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HStack(spacing: 0) {
                navigation

                Divider()

                selectedPageView
            }
        }
        .background(AppTheme.windowSurface)
    }

    private var navigation: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Page.allCases) { page in
                Button {
                    selectedPage = page
                } label: {
                    Label(page.title, systemImage: page.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedPage == page ? AppTheme.accentDeep : .primary)
                .background(
                    selectedPage == page ? AppTheme.accent.opacity(0.16) : .clear,
                    in: .rect(cornerRadius: 8)
                )
            }

            Spacer()
        }
        .padding(12)
        .frame(width: 164)
        .background(.primary.opacity(0.025))
    }

    @ViewBuilder
    private var selectedPageView: some View {
        switch selectedPage {
        case .general:
            GeneralSettingsView(
                appearanceStore: appearanceStore,
                menuBarStore: menuBarStore,
                shortcutStore: shortcutStore,
                shortcutErrorMessage: shortcutErrorMessage,
                updateTranslationShortcut: updateTranslationShortcut,
                updateScreenshotShortcut: updateScreenshotShortcut,
                updateSaveShortcut: updateSaveShortcut,
                selectedTextReader: selectedTextReader,
                pronunciationCache: pronunciationCache
            )
        case .apiKeys:
            APIKeySettingsView(
                configurationStore: configurationStore,
                languageModelProvider: languageModelProvider,
                ttsProvider: ttsProvider
            )
        case .providers:
            ProviderSelectionSettingsView(configurationStore: configurationStore)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("设置")
                    .font(.title2.weight(.bold))

                Text("调整通用偏好、API Key 与服务 Provider。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(AppIconButtonStyle())
            .keyboardShortcut(.cancelAction)
            .help("关闭设置")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }
}
