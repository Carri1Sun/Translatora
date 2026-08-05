import Foundation
import Testing
@testable import Translatora

@MainActor
struct MiniMaxTTSProviderTests {
    @Test
    func synthesizesMP3WithConfiguredVoice() async throws {
        let responseData = Data(
            """
            {
              "data": {"audio": "494433", "status": 2},
              "base_resp": {"status_code": 0, "status_msg": "success"}
            }
            """.utf8
        )
        let session = MiniMaxTTSStubSession(
            statusCode: 200,
            responseData: responseData
        )
        let provider = MiniMaxTTSProvider(
            configuration: MiniMaxConfiguration(
                apiKey: "  tts-key  ",
                model: .m3,
                ttsVoice: .englishTrustworthyMan
            ),
            session: session
        )

        let response = try await provider.synthesize(
            TTSRequest(text: "  pronunciation  ", language: .english)
        )

        #expect(response.audioData == Data([0x49, 0x44, 0x33]))
        #expect(response.fileExtension == "mp3")
        #expect(response.model == "speech-2.8-hd")

        let request = try #require(await session.lastRequest)
        #expect(request.url?.absoluteString == "https://api.minimaxi.com/v1/t2a_v2")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tts-key")

        let bodyData = try #require(request.httpBody)
        let body = try #require(
            JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        )
        #expect(body["model"] as? String == "speech-2.8-hd")
        #expect(body["text"] as? String == "pronunciation")
        #expect(body["language_boost"] as? String == "English")
        #expect(body["output_format"] as? String == "hex")
        let voice = try #require(body["voice_setting"] as? [String: Any])
        #expect(voice["voice_id"] as? String == "English_Trustworthy_Man")
    }

    @Test
    func surfacesEmbeddedServiceError() async {
        let session = MiniMaxTTSStubSession(
            statusCode: 200,
            responseData: Data(
                """
                {
                  "base_resp": {"status_code": 1004, "status_msg": "insufficient balance"}
                }
                """.utf8
            )
        )
        let provider = MiniMaxTTSProvider(
            configuration: MiniMaxConfiguration(apiKey: "tts-key", model: .m3),
            session: session
        )

        await #expect(
            throws: TTSProviderError.service(
                provider: "MiniMax",
                message: "insufficient balance"
            )
        ) {
            try await provider.synthesize(
                TTSRequest(text: "hello", language: .english)
            )
        }
    }
}

private actor MiniMaxTTSStubSession: NetworkSession {
    private let statusCode: Int
    private let responseData: Data
    private(set) var lastRequest: URLRequest?

    init(statusCode: Int, responseData: Data) {
        self.statusCode = statusCode
        self.responseData = responseData
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (responseData, response)
    }
}
