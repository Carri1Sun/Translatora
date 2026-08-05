import Foundation

struct QwenProvider: LLMProvider {
    private let configuration: QwenConfiguration
    private let session: any NetworkSession
    private let baseURL: URL

    init(
        configuration: QwenConfiguration,
        session: any NetworkSession = URLSession.shared,
        baseURL: URL? = nil
    ) {
        let configuration = configuration.normalized
        self.configuration = configuration
        self.session = session
        self.baseURL = baseURL ?? configuration.region.baseURL
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        try validateConfiguration()

        let body = QwenChatCompletionRequest(
            model: configuration.model.rawValue,
            messages: request.messages,
            temperature: request.temperature,
            maxTokens: request.maxTokens,
            enableThinking: false
        )
        let urlRequest = try makeRequest(
            path: "chat/completions",
            method: "POST",
            body: body
        )
        let data = try await send(urlRequest)

        guard
            let response = try? JSONDecoder().decode(
                QwenChatCompletionResponse.self,
                from: data
            ),
            let content = response.choices.first?.message.content,
            !content.isEmpty
        else {
            throw LLMProviderError.invalidResponse
        }

        return LLMResponse(content: content, model: response.model)
    }

    func testConnection() async throws {
        _ = try await complete(
            LLMRequest(
                messages: [LLMMessage(role: .user, content: "Reply with OK.")],
                maxTokens: 8
            )
        )
    }

    private func validateConfiguration() throws {
        guard !configuration.apiKey.isEmpty else {
            throw LLMProviderError.missingAPIKey("Qwen Token Plan")
        }
    }

    private func makeRequest<Body: Encodable>(
        path: String,
        method: String,
        body: Body
    ) throws -> URLRequest {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Bearer \(configuration.apiKey)",
            forHTTPHeaderField: "Authorization"
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LLMProviderError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(QwenAPIErrorResponse.self, from: data)
            let fallbackMessage = HTTPURLResponse.localizedString(
                forStatusCode: httpResponse.statusCode
            )
            throw LLMProviderError.api(
                provider: "Qwen Token Plan",
                statusCode: httpResponse.statusCode,
                message: apiError?.resolvedMessage ?? fallbackMessage
            )
        }

        return data
    }
}

private struct QwenChatCompletionRequest: Encodable {
    let model: String
    let messages: [LLMMessage]
    let temperature: Double?
    let maxTokens: Int?
    let enableThinking: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case enableThinking = "enable_thinking"
    }
}

private struct QwenChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        let message: LLMMessage
    }

    let model: String
    let choices: [Choice]
}

private struct QwenAPIErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String?
    }

    let error: APIError?
    let message: String?
    let code: String?

    var resolvedMessage: String? {
        error?.message ?? message ?? code
    }
}
