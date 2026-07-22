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
    @ObservedObject var shortcutStore: ShortcutStore
    let shortcutErrorMessage: String?
    let updateShortcut: (GlobalShortcut) -> Bool
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

            Section("翻译浮窗快捷键") {
                HStack(spacing: 12) {
                    Text("全局快捷键")

                    Spacer()

                    ShortcutRecorderView(
                        shortcut: shortcutStore.shortcut,
                        onChange: applyShortcut,
                        onValidationError: { message in
                            shortcutValidationError = message
                        }
                    )
                    .frame(width: 190)

                    Button("恢复默认") {
                        applyShortcut(.default)
                    }
                    .disabled(shortcutStore.shortcut == .default)
                }

                Text("点击快捷键后直接按下新的组合；组合中至少需要一个修饰键。按 Esc 可取消录制。")
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

                Text("用于在按下 \(shortcutStore.shortcut.displayName) 时读取其他应用当前选中的文本；权限缺失不会影响手动输入翻译。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
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

    private var isTesting: Bool {
        feedback == .testing
    }

    private var draftConfiguration: DeepSeekConfiguration {
        DeepSeekConfiguration(apiKey: apiKey, model: selectedModel).normalized
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

    private func applyShortcut(_ shortcut: GlobalShortcut) {
        shortcutValidationError = nil
        _ = updateShortcut(shortcut)
    }
}

#Preview {
    let store = ConfigurationStore()
    DeepSeekSettingsView(
        configurationStore: store,
        modelProvider: ModelProvider(configurationStore: store),
        appearanceStore: AppearanceStore(),
        shortcutStore: ShortcutStore(),
        shortcutErrorMessage: nil,
        updateShortcut: { _ in true },
        selectedTextReader: SelectedTextReader()
    )
}
