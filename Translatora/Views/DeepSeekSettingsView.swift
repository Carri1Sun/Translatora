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

    @State private var apiKey = ""
    @State private var selectedModel = DeepSeekModel.v4Flash
    @State private var feedback = Feedback.none

    var body: some View {
        Form {
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
                    .disabled(isTesting)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .onAppear(perform: loadSavedConfiguration)
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
}

#Preview {
    let store = ConfigurationStore()
    DeepSeekSettingsView(
        configurationStore: store,
        modelProvider: ModelProvider(configurationStore: store)
    )
}
