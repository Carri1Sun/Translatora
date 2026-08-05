import Foundation

enum LLMRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

struct LLMMessage: Codable, Equatable, Sendable {
    let role: LLMRole
    let content: String
}

struct LLMRequest: Equatable, Sendable {
    let messages: [LLMMessage]
    var temperature: Double?
    var maxTokens: Int?

    init(
        messages: [LLMMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

struct LLMResponse: Equatable, Sendable {
    let content: String
    let model: String
}

enum LLMProviderError: LocalizedError, Equatable {
    case missingAPIKey(String)
    case invalidResponse
    case modelUnavailable(String)
    case api(provider: String, statusCode: Int, message: String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case let .missingAPIKey(provider):
            "请先输入 \(provider) API Key"
        case .invalidResponse:
            "服务返回了无法解析的数据"
        case let .modelUnavailable(model):
            "当前账号无法使用模型：\(model)"
        case let .api(provider, statusCode, message):
            "\(provider) 请求失败（\(statusCode)）：\(message)"
        case let .transport(message):
            "网络连接失败：\(message)"
        }
    }
}

protocol LanguageModelProvider {
    func complete(_ request: LLMRequest) async throws -> LLMResponse
    func testConnection() async throws
}

@MainActor
protocol LanguageModelCompleting {
    func complete(_ request: LLMRequest) async throws -> LLMResponse
}
