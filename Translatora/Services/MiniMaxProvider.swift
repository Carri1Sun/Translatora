import Foundation

struct MiniMaxProvider: LanguageModelProvider {
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

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        try validateConfiguration()

        let body = MiniMaxChatCompletionRequest(
            model: configuration.model.rawValue,
            messages: request.messages,
            temperature: request.temperature,
            maxCompletionTokens: request.maxTokens,
            reasoningSplit: true,
            thinking: configuration.model == .m3 ? .disabled : nil
        )
        let urlRequest = try makeRequest(
            path: "chat/completions",
            method: "POST",
            body: body
        )
        let data = try await send(urlRequest)

        guard
            let response = try? JSONDecoder().decode(
                MiniMaxChatCompletionResponse.self,
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
        try validateConfiguration()

        let urlRequest = makeRequest(path: "models", method: "GET")
        let data = try await send(urlRequest)

        guard let response = try? JSONDecoder().decode(
            MiniMaxModelsResponse.self,
            from: data
        ) else {
            throw LLMProviderError.invalidResponse
        }

        guard response.data.contains(where: { $0.id == configuration.model.rawValue }) else {
            throw LLMProviderError.modelUnavailable(configuration.model.displayName)
        }
    }

    private func validateConfiguration() throws {
        guard !configuration.apiKey.isEmpty else {
            throw LLMProviderError.missingAPIKey("MiniMax")
        }
    }

    private func makeRequest<Body: Encodable>(
        path: String,
        method: String,
        body: Body
    ) throws -> URLRequest {
        var request = makeRequest(path: path, method: method)
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func makeRequest(path: String, method: String) -> URLRequest {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
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
            let apiError = try? JSONDecoder().decode(MiniMaxAPIErrorResponse.self, from: data)
            let fallbackMessage = HTTPURLResponse.localizedString(
                forStatusCode: httpResponse.statusCode
            )
            throw LLMProviderError.api(
                provider: "MiniMax",
                statusCode: httpResponse.statusCode,
                message: apiError?.error?.message
                    ?? apiError?.baseResponse?.statusMessage
                    ?? fallbackMessage
            )
        }

        return data
    }
}

private struct MiniMaxChatCompletionRequest: Encodable {
    let model: String
    let messages: [LLMMessage]
    let temperature: Double?
    let maxCompletionTokens: Int?
    let reasoningSplit: Bool
    let thinking: MiniMaxThinking?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxCompletionTokens = "max_completion_tokens"
        case reasoningSplit = "reasoning_split"
        case thinking
    }
}

private struct MiniMaxThinking: Encodable {
    let type: String

    static let disabled = MiniMaxThinking(type: "disabled")
}

private struct MiniMaxChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        let message: LLMMessage
    }

    let model: String
    let choices: [Choice]
}

private struct MiniMaxModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }

    let data: [Model]
}

private struct MiniMaxAPIErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    struct BaseResponse: Decodable {
        let statusMessage: String

        enum CodingKeys: String, CodingKey {
            case statusMessage = "status_msg"
        }
    }

    let error: APIError?
    let baseResponse: BaseResponse?

    enum CodingKeys: String, CodingKey {
        case error
        case baseResponse = "base_resp"
    }
}
