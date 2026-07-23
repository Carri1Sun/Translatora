import SwiftUI

struct SettingsCardView: View {
    @ObservedObject var configurationStore: ConfigurationStore
    let modelProvider: ModelProvider
    @ObservedObject var appearanceStore: AppearanceStore
    @ObservedObject var menuBarStore: MenuBarStore
    @ObservedObject var shortcutStore: ShortcutStore
    let shortcutErrorMessage: String?
    let updateTranslationShortcut: (GlobalShortcut?) -> Bool
    let updateSaveShortcut: (GlobalShortcut?) -> Bool
    let selectedTextReader: SelectedTextReader
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            DeepSeekSettingsView(
                configurationStore: configurationStore,
                modelProvider: modelProvider,
                appearanceStore: appearanceStore,
                menuBarStore: menuBarStore,
                shortcutStore: shortcutStore,
                shortcutErrorMessage: shortcutErrorMessage,
                updateTranslationShortcut: updateTranslationShortcut,
                updateSaveShortcut: updateSaveShortcut,
                selectedTextReader: selectedTextReader
            )
        }
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("设置")
                    .font(.title2.weight(.bold))

                Text("调整外观、菜单栏、快捷键与翻译服务。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.glass(.regular.interactive()))
            .buttonBorderShape(.circle)
            .keyboardShortcut(.cancelAction)
            .help("关闭设置")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }
}
