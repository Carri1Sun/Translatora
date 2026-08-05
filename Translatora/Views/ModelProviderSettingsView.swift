import SwiftUI

struct ModelProviderSettingsView: View {
    private enum Feedback: Equatable {
        case none
        case saved
        case testing
        case connected
        case failed(String)
    }

    @ObservedObject var configurationStore: ConfigurationStore
    let languageModelProvider: LanguageModelProviderRouter

    @State private var selectedLanguageProvider = LanguageModelProviderKind.deepSeek
    @State private var selectedTTSProvider = TTSProviderKind.qwen
    @State private var deepSeekAPIKey = ""
    @State private var deepSeekModel = DeepSeekModel.v4Flash
    @State private var miniMaxAPIKey = ""
    @State private var miniMaxModel = MiniMaxModel.m3
    @State private var qwenAPIKey = ""
    @State private var qwenModel = QwenModel.v38Max
    @State private var qwenRegion = QwenTokenPlanRegion.international
    @State private var feedback = Feedback.none

    var body: some View {
        Form {
            Section("翻译服务") {
                Picker("翻译 Provider", selection: $selectedLanguageProvider) {
                    ForEach(LanguageModelProviderKind.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                Text("保存后，新的翻译请求将使用所选 Provider。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("朗读服务") {
                Picker("朗读 Provider", selection: $selectedTTSProvider) {
                    ForEach(TTSProviderKind.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                Text("朗读服务独立于翻译服务选择，并复用对应 Provider 的 API Key。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            providerConfigurationSections

            Section {
                HStack {
                    feedbackView

                    Spacer()

                    Button("测试翻译连接") {
                        testConnection()
                    }
                    .disabled(isTesting || activeAPIKey.isEmpty)

                    Button("保存并启用") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentDeep)
                    .disabled(isTesting)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: loadSavedConfiguration)
        .onChange(of: selectedLanguageProvider) { _, _ in clearFeedbackAfterEditing() }
        .onChange(of: selectedTTSProvider) { _, _ in clearFeedbackAfterEditing() }
        .onChange(of: deepSeekAPIKey) { _, _ in clearFeedbackAfterEditing() }
        .onChange(of: deepSeekModel) { _, _ in clearFeedbackAfterEditing() }
        .onChange(of: miniMaxAPIKey) { _, _ in clearFeedbackAfterEditing() }
        .onChange(of: miniMaxModel) { _, _ in clearFeedbackAfterEditing() }
        .onChange(of: qwenAPIKey) { _, _ in clearFeedbackAfterEditing() }
        .onChange(of: qwenModel) { _, _ in clearFeedbackAfterEditing() }
        .onChange(of: qwenRegion) { _, _ in clearFeedbackAfterEditing() }
    }

    private var deepSeekSection: some View {
        Section("DeepSeek API") {
            SecureField("API Key", text: $deepSeekAPIKey)
                .textFieldStyle(.roundedBorder)

            Picker("模型", selection: $deepSeekModel) {
                ForEach(DeepSeekModel.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }

            Text(deepSeekModel.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var miniMaxSection: some View {
        Section("MiniMax 国内版") {
            SecureField("Token Plan Key 或按量计费 API Key", text: $miniMaxAPIKey)
                .textFieldStyle(.roundedBorder)

            Picker("模型", selection: $miniMaxModel) {
                ForEach(MiniMaxModel.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }

            Text(miniMaxModel.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("国内版使用 api.minimaxi.com。Token Plan Key 与普通按量计费 API Key 相互独立；高速模型需要对应套餐权限。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var qwenSection: some View {
        Section("Qwen Token Plan") {
            SecureField("Token Plan 专用 API Key", text: $qwenAPIKey)
                .textFieldStyle(.roundedBorder)

            Picker("模型", selection: $qwenModel) {
                ForEach(QwenModel.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }

            Text(qwenModel.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("服务区域", selection: $qwenRegion) {
                ForEach(QwenTokenPlanRegion.allCases) { region in
                    Text(region.displayName).tag(region)
                }
            }

            Text("请选择 Token Plan API Keys 页面显示的区域。专用 Key 不能用于按量计费或 Coding Plan 地址。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var providerConfigurationSections: some View {
        switch selectedLanguageProvider {
        case .deepSeek:
            deepSeekSection
        case .miniMax:
            miniMaxSection
        case .qwen:
            qwenSection
        }

        if selectedTTSProvider == .miniMax,
           selectedLanguageProvider != .miniMax {
            miniMaxSection
        }

        if selectedTTSProvider == .qwen,
           selectedLanguageProvider != .qwen {
            qwenSection
        }
    }

    @ViewBuilder
    private var feedbackView: some View {
        switch feedback {
        case .none:
            EmptyView()
        case .saved:
            Label("已保存并启用", systemImage: "checkmark.circle.fill")
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

    private var isTesting: Bool {
        feedback == .testing
    }

    private var activeAPIKey: String {
        switch selectedLanguageProvider {
        case .deepSeek:
            normalized(deepSeekAPIKey)
        case .miniMax:
            normalized(miniMaxAPIKey)
        case .qwen:
            normalized(qwenAPIKey)
        }
    }

    private var deepSeekDraft: DeepSeekConfiguration {
        DeepSeekConfiguration(
            apiKey: deepSeekAPIKey,
            model: deepSeekModel
        ).normalized
    }

    private var miniMaxDraft: MiniMaxConfiguration {
        MiniMaxConfiguration(
            apiKey: miniMaxAPIKey,
            model: miniMaxModel
        ).normalized
    }

    private var qwenDraft: QwenConfiguration {
        QwenConfiguration(
            apiKey: qwenAPIKey,
            model: qwenModel,
            region: qwenRegion
        ).normalized
    }

    private func loadSavedConfiguration() {
        selectedLanguageProvider = configurationStore.selectedLanguageProvider
        selectedTTSProvider = configurationStore.selectedTTSProvider
        deepSeekAPIKey = configurationStore.deepSeekConfiguration.apiKey
        deepSeekModel = configurationStore.deepSeekConfiguration.model
        miniMaxAPIKey = configurationStore.miniMaxConfiguration.apiKey
        miniMaxModel = configurationStore.miniMaxConfiguration.model
        qwenAPIKey = configurationStore.qwenConfiguration.apiKey
        qwenModel = configurationStore.qwenConfiguration.model
        qwenRegion = configurationStore.qwenConfiguration.region
        feedback = .none
    }

    private func save() {
        configurationStore.saveDeepSeekConfiguration(deepSeekDraft)
        configurationStore.saveMiniMaxConfiguration(miniMaxDraft)
        configurationStore.saveQwenConfiguration(qwenDraft)
        configurationStore.selectLanguageProvider(selectedLanguageProvider)
        configurationStore.selectTTSProvider(selectedTTSProvider)
        deepSeekAPIKey = normalized(deepSeekAPIKey)
        miniMaxAPIKey = normalized(miniMaxAPIKey)
        qwenAPIKey = normalized(qwenAPIKey)
        feedback = .saved
    }

    private func testConnection() {
        feedback = .testing

        Task {
            do {
                switch selectedLanguageProvider {
                case .deepSeek:
                    try await languageModelProvider.testConnection(using: deepSeekDraft)
                case .miniMax:
                    try await languageModelProvider.testConnection(using: miniMaxDraft)
                case .qwen:
                    try await languageModelProvider.testConnection(using: qwenDraft)
                }
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

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    let store = ConfigurationStore()
    ModelProviderSettingsView(
        configurationStore: store,
        languageModelProvider: LanguageModelProviderRouter(configurationStore: store)
    )
    .frame(width: 540, height: 560)
}
