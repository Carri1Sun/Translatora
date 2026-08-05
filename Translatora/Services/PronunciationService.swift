import AVFoundation
import Combine
import Foundation

@MainActor
final class PronunciationService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var loadingIdentifier: String?
    @Published private(set) var playingIdentifier: String?
    @Published private(set) var errorMessage: String?

    let cache: SpeechAudioCache

    private let ttsProvider: any TTSSynthesizing
    private var playbackTask: Task<Void, Never>?
    private var audioPlayer: AVAudioPlayer?

    init(
        ttsProvider: any TTSSynthesizing,
        cache: SpeechAudioCache
    ) {
        self.ttsProvider = ttsProvider
        self.cache = cache
        super.init()
    }

    func pronounce(_ text: String, language: TranslationLanguage) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let identifier = SpeechAudioCache.identifier(for: text)
        guard loadingIdentifier != identifier else { return }

        playbackTask?.cancel()
        audioPlayer?.stop()
        audioPlayer = nil
        playingIdentifier = nil
        loadingIdentifier = identifier
        errorMessage = nil

        playbackTask = Task { [weak self] in
            guard let self else { return }

            do {
                let fileURL: URL
                if let cachedURL = await cache.cachedFileURL(for: text) {
                    fileURL = cachedURL
                } else {
                    let response = try await ttsProvider.synthesize(
                        TTSRequest(text: text, language: language)
                    )
                    try Task.checkCancellation()
                    fileURL = try await cache.store(response.audioData, for: text)
                }

                try Task.checkCancellation()
                try play(fileURL, identifier: identifier)
            } catch is CancellationError {
                if loadingIdentifier == identifier {
                    loadingIdentifier = nil
                }
            } catch {
                if loadingIdentifier == identifier {
                    loadingIdentifier = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func isLoading(_ text: String) -> Bool {
        loadingIdentifier == SpeechAudioCache.identifier(for: text)
    }

    func isPlaying(_ text: String) -> Bool {
        playingIdentifier == SpeechAudioCache.identifier(for: text)
    }

    func dismissError() {
        errorMessage = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if audioPlayer === player {
            audioPlayer = nil
            playingIdentifier = nil
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if audioPlayer === player {
            audioPlayer = nil
            playingIdentifier = nil
            errorMessage = error?.localizedDescription ?? "无法解码语音文件"
        }
    }

    private func play(_ fileURL: URL, identifier: String) throws {
        let player = try AVAudioPlayer(contentsOf: fileURL)
        player.delegate = self
        guard player.prepareToPlay(), player.play() else {
            throw TTSProviderError.invalidResponse
        }

        audioPlayer = player
        loadingIdentifier = nil
        playingIdentifier = identifier
    }
}
