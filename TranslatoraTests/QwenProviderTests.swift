import Foundation
import Testing
@testable import Translatora

@MainActor
struct QwenProviderTests {
    @Test
    func sendsOpenAICompatibleCompletionRequestToTokenPlanEndpoint() async throws {
        let responseData = Data(
            """
            {
              "model": "qwen3.8-max",
              "choices": [
                {"message": {"role": "assistant", "content": "{\\"translation\\":\\"你好\\",\\"examples\\":[]}"}}
              ]
            }
            """.utf8
        )
        let session = QwenStubSession(statusCode: 200, responseData: responseData)
        let provider = QwenProvider(
            configuration: QwenConfiguration(
                apiKey: "  token-plan-key  ",
                model: .v38Max,
                region: .international
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

        #expect(response.model == "qwen3.8-max")
        #expect(response.content.contains("你好"))

        let request = try #require(await session.lastRequest)
        #expect(
            request.url?.absoluteString
                == "https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1/chat/completions"
        )
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token-plan-key")

        let bodyData = try #require(request.httpBody)
        let body = try #require(
            JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        )
        #expect(body["model"] as? String == "qwen3.8-max")
        #expect(body["max_tokens"] as? Int == 1_200)
        #expect(body["enable_thinking"] as? Bool == false)
    }

    @Test
    func usesChinaEndpointWhenSelected() async throws {
        let session = QwenStubSession(
            statusCode: 200,
            responseData: Data(
                """
                {
                  "model": "qwen3.6-flash",
                  "choices": [{"message": {"role": "assistant", "content": "OK"}}]
                }
                """.utf8
            )
        )
        let provider = QwenProvider(
            configuration: QwenConfiguration(
                apiKey: "token-plan-key",
                model: .v36Flash,
                region: .china
            ),
            session: session
        )

        try await provider.testConnection()

        let request = try #require(await session.lastRequest)
        #expect(
            request.url?.absoluteString
                == "https://token-plan.cn-beijing.maas.aliyuncs.com/compatible-mode/v1/chat/completions"
        )
        let bodyData = try #require(request.httpBody)
        let body = try #require(
            JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        )
        #expect(body["model"] as? String == "qwen3.6-flash")
        #expect(body["max_tokens"] as? Int == 8)
    }

    @Test
    func rejectsMissingAPIKeyBeforeSendingRequest() async {
        let session = QwenStubSession(statusCode: 200, responseData: Data())
        let provider = QwenProvider(configuration: .empty, session: session)

        await #expect(throws: LLMProviderError.missingAPIKey("Qwen Token Plan")) {
            try await provider.testConnection()
        }
        #expect(await session.lastRequest == nil)
    }

    @Test
    func surfacesTopLevelAPIErrorMessage() async {
        let session = QwenStubSession(
            statusCode: 401,
            responseData: Data(
                """
                {"code":"InvalidApiKey","message":"Invalid API-key provided."}
                """.utf8
            )
        )
        let provider = QwenProvider(
            configuration: QwenConfiguration(
                apiKey: "wrong-key",
                model: .v38Max,
                region: .international
            ),
            session: session
        )

        await #expect(
            throws: LLMProviderError.api(
                provider: "Qwen Token Plan",
                statusCode: 401,
                message: "Invalid API-key provided."
            )
        ) {
            try await provider.testConnection()
        }
    }
}

private actor QwenStubSession: NetworkSession {
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
