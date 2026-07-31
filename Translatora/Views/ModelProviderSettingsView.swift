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
    let modelProvider: ModelProvider

    @State private var selectedProvider = ModelProviderKind.deepSeek
    @State private var deepSeekAPIKey = ""
    @State private var deepSeekModel = DeepSeekModel.v4Flash
    @State private var miniMaxAPIKey = ""
    @State private var miniMaxModel = MiniMaxModel.m3
    @State private var feedback = Feedback.none

    var body: some View {
        Form {
            Section("翻译服务") {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(ModelProviderKind.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                Text("保存后，新的翻译请求将使用所选 Provider。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            switch selectedProvider {
            case .deepSeek:
                deepSeekSection
            case .miniMax:
                miniMaxSection
            }

            Section {
                HStack {
                    feedbackView

                    Spacer()

                    Button("测试连接") {
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
        .onChange(of: selectedProvider) { _, _ in clearFeedbackAfterEditing() }
        .onChange(of: deepSeekAPIKey) { _, _ in clearFeedbackAfterEditing() }
        .onChange(of: deepSeekModel) { _, _ in clearFeedbackAfterEditing() }
        .onChange(of: miniMaxAPIKey) { _, _ in clearFeedbackAfterEditing() }
        .onChange(of: miniMaxModel) { _, _ in clearFeedbackAfterEditing() }
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
        switch selectedProvider {
        case .deepSeek:
            normalized(deepSeekAPIKey)
        case .miniMax:
            normalized(miniMaxAPIKey)
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

    private func loadSavedConfiguration() {
        selectedProvider = configurationStore.selectedProvider
        deepSeekAPIKey = configurationStore.deepSeekConfiguration.apiKey
        deepSeekModel = configurationStore.deepSeekConfiguration.model
        miniMaxAPIKey = configurationStore.miniMaxConfiguration.apiKey
        miniMaxModel = configurationStore.miniMaxConfiguration.model
        feedback = .none
    }

    private func save() {
        configurationStore.saveDeepSeekConfiguration(deepSeekDraft)
        configurationStore.saveMiniMaxConfiguration(miniMaxDraft)
        configurationStore.selectProvider(selectedProvider)
        deepSeekAPIKey = normalized(deepSeekAPIKey)
        miniMaxAPIKey = normalized(miniMaxAPIKey)
        feedback = .saved
    }

    private func testConnection() {
        feedback = .testing

        Task {
            do {
                switch selectedProvider {
                case .deepSeek:
                    try await modelProvider.testConnection(using: deepSeekDraft)
                case .miniMax:
                    try await modelProvider.testConnection(using: miniMaxDraft)
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
        modelProvider: ModelProvider(configurationStore: store)
    )
    .frame(width: 540, height: 560)
}
