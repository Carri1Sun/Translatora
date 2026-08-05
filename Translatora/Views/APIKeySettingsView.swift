import AVFoundation
import SwiftUI

struct APIKeySettingsView: View {
    private enum TestTarget: Hashable {
        case deepSeekLanguage
        case miniMaxLanguage
        case miniMaxTTS
        case qwenLanguage
        case qwenTTS
    }

    private enum Feedback: Equatable {
        case connected(String)
        case failed(String)
    }

    @ObservedObject var configurationStore: ConfigurationStore
    let languageModelProvider: LanguageModelProviderRouter
    let ttsProvider: TTSProviderRouter

    @State private var deepSeekAPIKey = ""
    @State private var deepSeekModel = DeepSeekModel.v4Flash
    @State private var miniMaxAPIKey = ""
    @State private var miniMaxModel = MiniMaxModel.m3
    @State private var qwenAPIKey = ""
    @State private var qwenModel = QwenModel.v38Max
    @State private var qwenRegion = QwenTokenPlanRegion.international
    @State private var testingTarget: TestTarget?
    @State private var feedback: [TestTarget: Feedback] = [:]
    @State private var lastTestTarget: [TestTarget: TestTarget] = [:]
    @State private var didSave = false
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        Form {
            deepSeekSection
            miniMaxSection
            qwenSection

            Section {
                HStack {
                    if didSave {
                        Label("API 配置已保存", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Spacer()

                    Button("保存全部 API 配置", action: save)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accentDeep)
                        .disabled(testingTarget != nil)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: loadSavedConfiguration)
        .onChange(of: deepSeekAPIKey) { _, _ in didSave = false }
        .onChange(of: deepSeekModel) { _, _ in didSave = false }
        .onChange(of: miniMaxAPIKey) { _, _ in didSave = false }
        .onChange(of: miniMaxModel) { _, _ in didSave = false }
        .onChange(of: qwenAPIKey) { _, _ in didSave = false }
        .onChange(of: qwenModel) { _, _ in didSave = false }
        .onChange(of: qwenRegion) { _, _ in didSave = false }
    }

    private var deepSeekSection: some View {
        Section("DeepSeek API") {
            SecureField("API Key", text: $deepSeekAPIKey)
                .textFieldStyle(.roundedBorder)

            Picker("翻译模型", selection: $deepSeekModel) {
                ForEach(DeepSeekModel.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }

            Text(deepSeekModel.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            testRow(target: .deepSeekLanguage) {
                testLanguage(target: .deepSeekLanguage)
            }
        }
    }

    private var miniMaxSection: some View {
        Section("MiniMax 国内版") {
            SecureField("Token Plan Key 或按量计费 API Key", text: $miniMaxAPIKey)
                .textFieldStyle(.roundedBorder)

            Picker("翻译模型", selection: $miniMaxModel) {
                ForEach(MiniMaxModel.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }

            Text(miniMaxModel.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            LabeledContent(
                "当前朗读音色",
                value: configurationStore.miniMaxConfiguration.ttsVoice.displayName
            )

            Text("朗读模型固定使用 speech-2.8-hd；音色请在 Provider 页面选择并保存。")
                .font(.caption)
                .foregroundStyle(.secondary)

            testRow(target: .miniMaxLanguage, secondaryTarget: .miniMaxTTS) {
                testLanguage(target: .miniMaxLanguage)
            } secondaryAction: {
                testTTS(target: .miniMaxTTS)
            }

            Text("国内版使用 api.minimaxi.com。Token Plan Key 与普通按量计费 API Key 相互独立；高速模型需要对应套餐权限。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var qwenSection: some View {
        Section("Qwen Token Plan") {
            SecureField("Token Plan 专用 API Key", text: $qwenAPIKey)
                .textFieldStyle(.roundedBorder)

            Picker("翻译模型", selection: $qwenModel) {
                ForEach(QwenModel.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }

            Text(qwenModel.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("翻译服务区域", selection: $qwenRegion) {
                ForEach(QwenTokenPlanRegion.allCases) { region in
                    Text(region.displayName).tag(region)
                }
            }

            LabeledContent(
                "当前朗读音色",
                value: configurationStore.qwenConfiguration.ttsVoice.displayName
            )

            Text("朗读模型固定使用 qwen-audio-3.0-tts-plus，并通过 Token Plan 新加坡 WebSocket 接入；音色请在 Provider 页面选择并保存。")
                .font(.caption)
                .foregroundStyle(.secondary)

            testRow(target: .qwenLanguage, secondaryTarget: .qwenTTS) {
                testLanguage(target: .qwenLanguage)
            } secondaryAction: {
                testTTS(target: .qwenTTS)
            }

            Text("请使用 Token Plan API Keys 页面生成的专用 Key（通常以 sk-sp- 开头）。该 Key 不能用于按量计费或 Coding Plan 地址。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func testRow(
        target: TestTarget,
        secondaryTarget: TestTarget? = nil,
        action: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        let isTesting = testingTarget == target || testingTarget == secondaryTarget
        let resultTarget = lastTestTarget[target] ?? target

        return HStack(alignment: .center, spacing: 10) {
            feedbackView(for: feedback[resultTarget], isTesting: isTesting)

            Spacer()

            Button("测试翻译", action: action)
                .disabled(testingTarget != nil || apiKey(for: target).isEmpty)

            if let secondaryTarget, let secondaryAction {
                Button("测试朗读并播放", action: secondaryAction)
                    .disabled(
                        testingTarget != nil || apiKey(for: secondaryTarget).isEmpty
                    )
            }
        }
    }

    @ViewBuilder
    private func feedbackView(for value: Feedback?, isTesting: Bool) -> some View {
        if isTesting {
            HStack(spacing: 7) {
                ProgressView()
                    .controlSize(.small)
                Text("正在测试…")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
            switch value {
            case let .connected(message):
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            case let .failed(message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .lineLimit(3)
            case nil:
                EmptyView()
            }
        }
    }

    private var deepSeekDraft: DeepSeekConfiguration {
        DeepSeekConfiguration(apiKey: deepSeekAPIKey, model: deepSeekModel).normalized
    }

    private var miniMaxDraft: MiniMaxConfiguration {
        MiniMaxConfiguration(
            apiKey: miniMaxAPIKey,
            model: miniMaxModel,
            ttsVoice: configurationStore.miniMaxConfiguration.ttsVoice
        ).normalized
    }

    private var qwenDraft: QwenConfiguration {
        QwenConfiguration(
            apiKey: qwenAPIKey,
            model: qwenModel,
            region: qwenRegion,
            ttsVoice: configurationStore.qwenConfiguration.ttsVoice
        ).normalized
    }

    private func loadSavedConfiguration() {
        let deepSeek = configurationStore.deepSeekConfiguration
        deepSeekAPIKey = deepSeek.apiKey
        deepSeekModel = deepSeek.model

        let miniMax = configurationStore.miniMaxConfiguration
        miniMaxAPIKey = miniMax.apiKey
        miniMaxModel = miniMax.model

        let qwen = configurationStore.qwenConfiguration
        qwenAPIKey = qwen.apiKey
        qwenModel = qwen.model
        qwenRegion = qwen.region

        testingTarget = nil
        feedback = [:]
        lastTestTarget = [:]
        didSave = false
    }

    private func save() {
        configurationStore.saveDeepSeekConfiguration(deepSeekDraft)
        configurationStore.saveMiniMaxConfiguration(miniMaxDraft)
        configurationStore.saveQwenConfiguration(qwenDraft)
        deepSeekAPIKey = deepSeekDraft.apiKey
        miniMaxAPIKey = miniMaxDraft.apiKey
        qwenAPIKey = qwenDraft.apiKey
        didSave = true
    }

    private func testLanguage(target: TestTarget) {
        beginTest(target)

        Task {
            do {
                switch target {
                case .deepSeekLanguage:
                    try await languageModelProvider.testConnection(using: deepSeekDraft)
                case .miniMaxLanguage:
                    try await languageModelProvider.testConnection(using: miniMaxDraft)
                case .qwenLanguage:
                    try await languageModelProvider.testConnection(using: qwenDraft)
                case .miniMaxTTS, .qwenTTS:
                    return
                }
                finishTest(target, with: .connected("翻译连接成功"))
            } catch {
                finishTest(target, with: .failed(error.localizedDescription))
            }
        }
    }

    private func testTTS(target: TestTarget) {
        beginTest(target)

        Task {
            do {
                let response: TTSResponse
                switch target {
                case .miniMaxTTS:
                    response = try await ttsProvider.testConnection(using: miniMaxDraft)
                case .qwenTTS:
                    response = try await ttsProvider.testConnection(using: qwenDraft)
                case .deepSeekLanguage, .miniMaxLanguage, .qwenLanguage:
                    return
                }

                let player = try AVAudioPlayer(data: response.audioData)
                player.prepareToPlay()
                guard player.play() else {
                    throw TTSProviderError.invalidResponse
                }
                audioPlayer = player
                finishTest(target, with: .connected("朗读连接成功，已播放"))
            } catch {
                finishTest(target, with: .failed(error.localizedDescription))
            }
        }
    }

    private func beginTest(_ target: TestTarget) {
        didSave = false
        feedback[target] = nil
        lastTestTarget[primaryTarget(for: target)] = target
        testingTarget = target
    }

    private func finishTest(_ target: TestTarget, with value: Feedback) {
        feedback[target] = value
        testingTarget = nil
    }

    private func apiKey(for target: TestTarget) -> String {
        switch target {
        case .deepSeekLanguage:
            deepSeekDraft.apiKey
        case .miniMaxLanguage, .miniMaxTTS:
            miniMaxDraft.apiKey
        case .qwenLanguage, .qwenTTS:
            qwenDraft.apiKey
        }
    }

    private func primaryTarget(for target: TestTarget) -> TestTarget {
        switch target {
        case .miniMaxTTS:
            .miniMaxLanguage
        case .qwenTTS:
            .qwenLanguage
        case .deepSeekLanguage, .miniMaxLanguage, .qwenLanguage:
            target
        }
    }
}

#Preview {
    let store = ConfigurationStore()
    APIKeySettingsView(
        configurationStore: store,
        languageModelProvider: LanguageModelProviderRouter(configurationStore: store),
        ttsProvider: TTSProviderRouter(configurationStore: store)
    )
    .frame(width: 596, height: 620)
}
