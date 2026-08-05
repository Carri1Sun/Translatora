import Foundation

struct MiniMaxTTSProvider: TTSProvider {
    static let model = "speech-2.8-hd"

    private let configuration: MiniMaxConfiguration
    private let session: any NetworkSession
    private let baseURL: URL

    init(
        configuration: MiniMaxConfiguration,
        session: any NetworkSession = URLSession.shared,
        baseURL: URL = URL(string: "https://api.minimaxi.com/v1")!
    ) {
        self.configuration = configuration.normalized
        self.session = session
        self.baseURL = baseURL
    }

    func synthesize(_ request: TTSRequest) async throws -> TTSResponse {
        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TTSProviderError.emptyText }
        guard !configuration.apiKey.isEmpty else {
            throw TTSProviderError.missingAPIKey("MiniMax")
        }

        let body = MiniMaxTTSRequest(
            model: Self.model,
            text: text,
            stream: false,
            languageBoost: request.language.miniMaxLanguageBoost,
            voiceSetting: MiniMaxVoiceSetting(
                voiceID: configuration.ttsVoice.voiceID(for: request.language),
                speed: 1,
                volume: 1,
                pitch: 0
            ),
            audioSetting: MiniMaxAudioSetting(
                sampleRate: 32_000,
                bitrate: 128_000,
                format: "mp3",
                channel: 1
            ),
            subtitleEnabled: false,
            outputFormat: "hex"
        )

        var urlRequest = URLRequest(url: baseURL.appending(path: "t2a_v2"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 60
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(
            "Bearer \(configuration.apiKey)",
            forHTTPHeaderField: "Authorization"
        )
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw TTSProviderError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSProviderError.invalidResponse
        }

        let payload = try? JSONDecoder().decode(MiniMaxTTSResponse.self, from: data)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TTSProviderError.api(
                provider: "MiniMax",
                statusCode: httpResponse.statusCode,
                message: payload?.baseResponse?.statusMessage
                    ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }

        if let baseResponse = payload?.baseResponse,
           baseResponse.statusCode != 0 {
            throw TTSProviderError.service(
                provider: "MiniMax",
                message: baseResponse.statusMessage
            )
        }

        guard let audioHex = payload?.data?.audio,
              let audioData = Data(hexEncoded: audioHex),
              !audioData.isEmpty else {
            throw TTSProviderError.invalidResponse
        }

        return TTSResponse(
            audioData: audioData,
            fileExtension: "mp3",
            model: Self.model
        )
    }
}

private struct MiniMaxTTSRequest: Encodable {
    let model: String
    let text: String
    let stream: Bool
    let languageBoost: String
    let voiceSetting: MiniMaxVoiceSetting
    let audioSetting: MiniMaxAudioSetting
    let subtitleEnabled: Bool
    let outputFormat: String

    enum CodingKeys: String, CodingKey {
        case model
        case text
        case stream
        case languageBoost = "language_boost"
        case voiceSetting = "voice_setting"
        case audioSetting = "audio_setting"
        case subtitleEnabled = "subtitle_enable"
        case outputFormat = "output_format"
    }
}

private struct MiniMaxVoiceSetting: Encodable {
    let voiceID: String
    let speed: Double
    let volume: Double
    let pitch: Int

    enum CodingKeys: String, CodingKey {
        case voiceID = "voice_id"
        case speed
        case volume = "vol"
        case pitch
    }
}

private struct MiniMaxAudioSetting: Encodable {
    let sampleRate: Int
    let bitrate: Int
    let format: String
    let channel: Int

    enum CodingKeys: String, CodingKey {
        case sampleRate = "sample_rate"
        case bitrate
        case format
        case channel
    }
}

private struct MiniMaxTTSResponse: Decodable {
    struct AudioPayload: Decodable {
        let audio: String?
    }

    struct BaseResponse: Decodable {
        let statusCode: Int
        let statusMessage: String

        enum CodingKeys: String, CodingKey {
            case statusCode = "status_code"
            case statusMessage = "status_msg"
        }
    }

    let data: AudioPayload?
    let baseResponse: BaseResponse?

    enum CodingKeys: String, CodingKey {
        case data
        case baseResponse = "base_resp"
    }
}

private extension TranslationLanguage {
    var miniMaxLanguageBoost: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese, .traditionalChinese: "Chinese"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .french: "French"
        case .german: "German"
        case .spanish: "Spanish"
        }
    }

}

private extension Data {
    init?(hexEncoded string: String) {
        let bytes = Array(string.utf8)
        guard bytes.count.isMultiple(of: 2) else { return nil }

        self.init(capacity: bytes.count / 2)
        var index = 0
        while index < bytes.count {
            guard let high = Self.hexNibble(bytes[index]),
                  let low = Self.hexNibble(bytes[index + 1]) else {
                return nil
            }
            append((high << 4) | low)
            index += 2
        }
    }

    static func hexNibble(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: byte - 48
        case 65...70: byte - 55
        case 97...102: byte - 87
        default: nil
        }
    }
}
