import SwiftUI

struct PronunciationButton: View {
    @ObservedObject var service: PronunciationService
    let text: String
    let language: TranslationLanguage

    var body: some View {
        Button {
            service.pronounce(text, language: language)
        } label: {
            HStack(spacing: 6) {
                if service.isLoading(text) {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(
                        systemName: service.isPlaying(text)
                            ? "speaker.wave.2.fill"
                            : "speaker.wave.2"
                    )
                }
                Text(service.isLoading(text) ? "生成中" : "读音")
            }
        }
        .buttonStyle(AppButtonStyle())
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .help("生成并播放原文读音")
        .accessibilityLabel("播放原文读音")
    }
}
