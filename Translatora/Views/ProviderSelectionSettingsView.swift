import SwiftUI

struct ProviderSelectionSettingsView: View {
    @ObservedObject var configurationStore: ConfigurationStore

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

                Text("朗读 Provider 独立于翻译 Provider，选择后立即生效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            set: configurationStore.selectTTSProvider
        )
    }
}

#Preview {
    ProviderSelectionSettingsView(configurationStore: ConfigurationStore())
        .frame(width: 596, height: 620)
}
