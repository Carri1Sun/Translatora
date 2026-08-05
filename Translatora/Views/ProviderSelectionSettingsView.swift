import SwiftUI

struct ProviderSelectionSettingsView: View {
    @ObservedObject var configurationStore: ConfigurationStore
    @State private var miniMaxVoice = MiniMaxTTSVoice.automatic
    @State private var qwenVoice = QwenTTSVoice.longXiaochun
    @State private var didSaveVoice = false

    var body: some View {
        Form {
            Section("翻译服务") {
                Picker("翻译 Provider", selection: languageProviderBinding) {
                    ForEach(LanguageModelProviderKind.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                Text("新的翻译请求将立即使用所选 Provider。API Key 与模型请在 API Key 页面配置。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("朗读服务") {
                Picker("朗读 Provider", selection: ttsProviderBinding) {
                    ForEach(TTSProviderKind.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                voicePicker

                HStack(spacing: 12) {
                    Text("朗读 Provider 选择后立即生效；音色需要单独保存。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if didSaveVoice {
                        Label("已保存", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    Button("保存音色", action: saveVoice)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accentDeep)
                }

                Text("切换音色后，清理通用设置中的语音缓存即可重新生成已朗读过的词条。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: loadSavedVoices)
        .onChange(of: miniMaxVoice) { _, _ in didSaveVoice = false }
        .onChange(of: qwenVoice) { _, _ in didSaveVoice = false }
    }

    @ViewBuilder
    private var voicePicker: some View {
        switch configurationStore.selectedTTSProvider {
        case .qwen:
            Picker("Qwen 音色", selection: $qwenVoice) {
                ForEach(QwenTTSVoice.allCases) { voice in
                    Text(voice.displayName).tag(voice)
                }
            }
        case .miniMax:
            Picker("MiniMax 音色", selection: $miniMaxVoice) {
                ForEach(MiniMaxTTSVoice.allCases) { voice in
                    Text(voice.displayName).tag(voice)
                }
            }
        }
    }

    private var languageProviderBinding: Binding<LanguageModelProviderKind> {
        Binding(
            get: { configurationStore.selectedLanguageProvider },
            set: configurationStore.selectLanguageProvider
        )
    }

    private var ttsProviderBinding: Binding<TTSProviderKind> {
        Binding(
            get: { configurationStore.selectedTTSProvider },
            set: { provider in
                configurationStore.selectTTSProvider(provider)
                didSaveVoice = false
            }
        )
    }

    private func loadSavedVoices() {
        miniMaxVoice = configurationStore.miniMaxConfiguration.ttsVoice
        qwenVoice = configurationStore.qwenConfiguration.ttsVoice
        didSaveVoice = false
    }

    private func saveVoice() {
        switch configurationStore.selectedTTSProvider {
        case .qwen:
            var configuration = configurationStore.qwenConfiguration
            configuration.ttsVoice = qwenVoice
            configurationStore.saveQwenConfiguration(configuration)
        case .miniMax:
            var configuration = configurationStore.miniMaxConfiguration
            configuration.ttsVoice = miniMaxVoice
            configurationStore.saveMiniMaxConfiguration(configuration)
        }
        didSaveVoice = true
    }
}

#Preview {
    ProviderSelectionSettingsView(configurationStore: ConfigurationStore())
        .frame(width: 596, height: 620)
}
