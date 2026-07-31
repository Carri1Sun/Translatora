import Foundation
import Testing
@testable import Translatora

@MainActor
struct MiniMaxProviderTests {
    @Test
    func sendsOpenAICompatibleCompletionRequestToChinaEndpoint() async throws {
        let responseData = Data(
            """
            {
              "model": "MiniMax-M3",
              "choices": [
                {"message": {"role": "assistant", "content": "{\\"translation\\":\\"你好\\",\\"examples\\":[]}"}}
              ]
            }
            """.utf8
        )
        let session = MiniMaxStubSession(
            statusCode: 200,
            responseData: responseData
        )
        let provider = MiniMaxProvider(
            configuration: MiniMaxConfiguration(
                apiKey: "  token-plan-key  ",
                model: .m3
            ),
            session: session
        )

        let response = try await provider.complete(
            LLMRequest(
                messages: [LLMMessage(role: .user, content: "hello")],
                temperature: 0.2,
                maxTokens: 1_200
            )
        )

        #expect(response.model == "MiniMax-M3")
        #expect(response.content.contains("你好"))

        let request = try #require(await session.lastRequest)
        #expect(request.url?.absoluteString == "https://api.minimaxi.com/v1/chat/completions")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token-plan-key")

        let bodyData = try #require(request.httpBody)
        let body = try #require(
            JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        )
        #expect(body["model"] as? String == "MiniMax-M3")
        #expect(body["max_completion_tokens"] as? Int == 1_200)
        #expect(body["reasoning_split"] as? Bool == true)
        let thinking = try #require(body["thinking"] as? [String: String])
        #expect(thinking["type"] == "disabled")
    }

    @Test
    func testsSelectedModelAvailability() async throws {
        let session = MiniMaxStubSession(
            statusCode: 200,
            responseData: Data(
                """
                {
                  "object": "list",
                  "data": [{"id": "MiniMax-M3"}, {"id": "MiniMax-M2.7-highspeed"}]
                }
                """.utf8
            )
        )
        let provider = MiniMaxProvider(
            configuration: MiniMaxConfiguration(
                apiKey: "token-plan-key",
                model: .m3
            ),
            session: session
        )

        try await provider.testConnection()

        let request = try #require(await session.lastRequest)
        #expect(request.url?.absoluteString == "https://api.minimaxi.com/v1/models")
        #expect(request.httpMethod == "GET")
    }

    @Test
    func rejectsMissingAPIKeyBeforeSendingRequest() async {
        let session = MiniMaxStubSession(statusCode: 200, responseData: Data())
        let provider = MiniMaxProvider(
            configuration: .empty,
            session: session
        )

        await #expect(throws: LLMProviderError.missingAPIKey("MiniMax")) {
            try await provider.testConnection()
        }
        #expect(await session.lastRequest == nil)
    }
}

private actor MiniMaxStubSession: NetworkSession {
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
