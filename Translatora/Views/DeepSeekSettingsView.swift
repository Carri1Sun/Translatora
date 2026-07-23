import SwiftUI

struct DeepSeekSettingsView: View {
    private enum Feedback: Equatable {
        case none
        case saved
        case testing
        case connected
        case failed(String)
    }

    @ObservedObject var configurationStore: ConfigurationStore
    let modelProvider: ModelProvider
    @ObservedObject var appearanceStore: AppearanceStore
    @ObservedObject var menuBarStore: MenuBarStore
    @ObservedObject var shortcutStore: ShortcutStore
    let shortcutErrorMessage: String?
    let updateTranslationShortcut: (GlobalShortcut?) -> Bool
    let updateSaveShortcut: (GlobalShortcut?) -> Bool
    let selectedTextReader: SelectedTextReader

    @State private var apiKey = ""
    @State private var selectedModel = DeepSeekModel.v4Flash
    @State private var feedback = Feedback.none
    @State private var isAccessibilityTrusted = false
    @State private var shortcutValidationError: String?

    var body: some View {
        Form {
            Section("外观") {
                Picker("显示模式", selection: appearanceBinding) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Label(appearance.displayName, systemImage: appearance.icon)
                            .tag(appearance)
                    }
                }
                .pickerStyle(.segmented)

                Text("翻译面板和词典会同步使用所选外观。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("菜单栏") {
                Toggle("显示菜单栏图标", isOn: menuBarVisibilityBinding)

                Text("隐藏后仍可通过应用首页的设置重新开启，Dock 中的 Translatora 也会继续保留。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("快捷键") {
                shortcutRow(
                    title: "打开翻译浮窗",
                    shortcut: shortcutStore.translationShortcut,
                    onChange: applyTranslationShortcut,
                    onDelete: { applyTranslationShortcut(nil) }
                )

                shortcutRow(
                    title: "保存词汇到词典",
                    shortcut: shortcutStore.saveShortcut,
                    onChange: applySaveShortcut,
                    onDelete: { applySaveShortcut(nil) }
                )

                Text("点击快捷键后直接按下新的组合；组合中至少需要一个修饰键。保存快捷键仅在翻译浮窗中生效，按 Esc 可取消录制。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let message = shortcutValidationError ?? shortcutErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("DeepSeek API") {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                Picker("模型", selection: $selectedModel) {
                    ForEach(DeepSeekModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }

                Text(selectedModel.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    feedbackView

                    Spacer()

                    Button("测试连接") {
                        testConnection()
                    }
                    .disabled(isTesting || normalizedAPIKey.isEmpty)

                    Button("保存") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentDeep)
                    .disabled(isTesting)
                }
            }

            Section("选中文本") {
                HStack {
                    Label(
                        isAccessibilityTrusted ? "已获得辅助功能权限" : "需要辅助功能权限",
                        systemImage: isAccessibilityTrusted
                            ? "checkmark.shield.fill"
                            : "lock.shield"
                    )
                    .foregroundStyle(isAccessibilityTrusted ? AppTheme.accentDeep : .secondary)

                    Spacer()

                    if !isAccessibilityTrusted {
                        Button("请求权限") {
                            requestAccessibilityAccess()
                        }
                    }

                    Button("系统设置") {
                        selectedTextReader.openAccessibilitySettings()
                    }
                }

                Text(accessibilityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(appearanceStore.appearance.colorScheme)
        .onAppear {
            loadSavedConfiguration()
            refreshAccessibilityStatus()
        }
        .onChange(of: apiKey) { _, _ in clearFeedbackAfterEditing() }
        .onChange(of: selectedModel) { _, _ in clearFeedbackAfterEditing() }
    }

    @ViewBuilder
    private var feedbackView: some View {
        switch feedback {
        case .none:
            EmptyView()
        case .saved:
            Label("已保存", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .testing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("正在测试…")
            }
            .foregroundStyle(.secondary)
        case .connected:
            Label("连接成功", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    private var normalizedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { appearanceStore.appearance },
            set: appearanceStore.setAppearance
        )
    }

    private var menuBarVisibilityBinding: Binding<Bool> {
        Binding(
            get: { menuBarStore.isVisible },
            set: menuBarStore.setVisible
        )
    }

    private var isTesting: Bool {
        feedback == .testing
    }

    private var draftConfiguration: DeepSeekConfiguration {
        DeepSeekConfiguration(apiKey: apiKey, model: selectedModel).normalized
    }

    private var accessibilityDescription: String {
        if let shortcut = shortcutStore.translationShortcut {
            return "用于在按下 \(shortcut.displayName) 时读取其他应用当前选中的文本；权限缺失不会影响手动输入翻译。"
        }
        return "用于从其他应用读取当前选中的文本；当前未设置打开翻译浮窗的快捷键，仍可从应用菜单手动打开。"
    }

    private func shortcutRow(
        title: String,
        shortcut: GlobalShortcut?,
        onChange: @escaping (GlobalShortcut) -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)

            Spacer()

            ShortcutRecorderView(
                shortcut: shortcut,
                onChange: onChange,
                onValidationError: { message in
                    shortcutValidationError = message
                }
            )
            .frame(width: 190)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .disabled(shortcut == nil)
            .help("删除快捷键")
        }
    }

    private func loadSavedConfiguration() {
        let configuration = configurationStore.deepSeekConfiguration
        apiKey = configuration.apiKey
        selectedModel = configuration.model
        feedback = .none
    }

    private func save() {
        configurationStore.saveDeepSeekConfiguration(draftConfiguration)
        apiKey = normalizedAPIKey
        feedback = .saved
    }

    private func testConnection() {
        let configuration = draftConfiguration
        feedback = .testing

        Task {
            do {
                try await modelProvider.testConnection(using: configuration)
                feedback = .connected
            } catch {
                feedback = .failed(error.localizedDescription)
            }
        }
    }

    private func clearFeedbackAfterEditing() {
        guard feedback != .testing else { return }
        feedback = .none
    }

    private func requestAccessibilityAccess() {
        isAccessibilityTrusted = selectedTextReader.requestAccessibilityAccess()
        if !isAccessibilityTrusted {
            selectedTextReader.openAccessibilitySettings()
        }
    }

    private func refreshAccessibilityStatus() {
        isAccessibilityTrusted = selectedTextReader.isAccessibilityTrusted
    }

    private func applyTranslationShortcut(_ shortcut: GlobalShortcut?) {
        shortcutValidationError = nil
        _ = updateTranslationShortcut(shortcut)
    }

    private func applySaveShortcut(_ shortcut: GlobalShortcut?) {
        shortcutValidationError = nil
        _ = updateSaveShortcut(shortcut)
    }
}

#Preview {
    let store = ConfigurationStore()
    DeepSeekSettingsView(
        configurationStore: store,
        modelProvider: ModelProvider(configurationStore: store),
        appearanceStore: AppearanceStore(),
        menuBarStore: MenuBarStore(),
        shortcutStore: ShortcutStore(),
        shortcutErrorMessage: nil,
        updateTranslationShortcut: { _ in true },
        updateSaveShortcut: { _ in true },
        selectedTextReader: SelectedTextReader()
    )
    .frame(width: 540, height: 560)
}
