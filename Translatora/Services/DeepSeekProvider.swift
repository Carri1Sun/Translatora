import Foundation

protocol NetworkSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSession {}

struct DeepSeekProvider: LLMProvider {
    private let configuration: DeepSeekConfiguration
    private let session: any NetworkSession
    private let baseURL: URL

    init(
        configuration: DeepSeekConfiguration,
        session: any NetworkSession = URLSession.shared,
        baseURL: URL = URL(string: "https://api.deepseek.com")!
    ) {
        self.configuration = configuration.normalized
        self.session = session
        self.baseURL = baseURL
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        try validateConfiguration()

        let body = ChatCompletionRequest(
            model: configuration.model.rawValue,
            messages: request.messages,
            temperature: request.temperature,
            maxTokens: request.maxTokens
        )
        let urlRequest = try makeRequest(path: "chat/completions", method: "POST", body: body)
        let data = try await send(urlRequest)

        guard
            let response = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data),
            let content = response.choices.first?.message.content,
            !content.isEmpty
        else {
            throw LLMProviderError.invalidResponse
        }

        return LLMResponse(content: content, model: response.model)
    }

    func testConnection() async throws {
        try validateConfiguration()

        let urlRequest = try makeRequest(path: "models", method: "GET")
        let data = try await send(urlRequest)

        guard let response = try? JSONDecoder().decode(ModelsResponse.self, from: data) else {
            throw LLMProviderError.invalidResponse
        }

        guard response.data.contains(where: { $0.id == configuration.model.rawValue }) else {
            throw LLMProviderError.modelUnavailable(configuration.model.displayName)
        }
    }

    private func validateConfiguration() throws {
        guard !configuration.apiKey.isEmpty else {
            throw LLMProviderError.missingAPIKey
        }
    }

    private func makeRequest<Body: Encodable>(
        path: String,
        method: String,
        body: Body
    ) throws -> URLRequest {
        var request = try makeRequest(path: path, method: method)
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
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
            let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            let fallbackMessage = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw LLMProviderError.api(
                statusCode: httpResponse.statusCode,
                message: apiError?.error.message ?? fallbackMessage
            )
        }

        return data
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [LLMMessage]
    let temperature: Double?
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        let message: LLMMessage
    }

    let model: String
    let choices: [Choice]
}

private struct ModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }

    let data: [Model]
}

private struct APIErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}
