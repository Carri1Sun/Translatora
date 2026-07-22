import SwiftUI

struct SettingsCardView: View {
    @ObservedObject var configurationStore: ConfigurationStore
    let modelProvider: ModelProvider
    @ObservedObject var appearanceStore: AppearanceStore
    @ObservedObject var shortcutStore: ShortcutStore
    let shortcutErrorMessage: String?
    let updateShortcut: (GlobalShortcut) -> Bool
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
                shortcutStore: shortcutStore,
                shortcutErrorMessage: shortcutErrorMessage,
                updateShortcut: updateShortcut,
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

                Text("调整外观、快捷键与翻译服务。")
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
