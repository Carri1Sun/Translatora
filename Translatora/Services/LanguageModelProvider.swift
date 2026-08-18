import Foundation

enum LLMRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

struct LLMMessage: Codable, Equatable, Sendable {
    let role: LLMRole
    let content: String
    let imageDataURL: String?

    init(role: LLMRole, content: String, imageDataURL: String? = nil) {
        self.role = role
        self.content = content
        self.imageDataURL = imageDataURL
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(LLMRole.self, forKey: .role)
        if let text = try? container.decode(String.self, forKey: .content) {
            content = text
            imageDataURL = nil
            return
        }

        let parts = try container.decode([LLMContentPart].self, forKey: .content)
        content = parts.compactMap(\.text).joined(separator: "\n")
        imageDataURL = parts.compactMap(\.imageURL?.url).first
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)

        guard let imageDataURL else {
            try container.encode(content, forKey: .content)
            return
        }

        try container.encode(
            [
                LLMContentPart(
                    type: .imageURL,
                    imageURL: LLMImageReference(url: imageDataURL)
                ),
                LLMContentPart(type: .text, text: content)
            ],
            forKey: .content
        )
    }
}

private struct LLMContentPart: Codable {
    enum ContentType: String, Codable {
        case text
        case imageURL = "image_url"
    }

    let type: ContentType
    var text: String?
    var imageURL: LLMImageReference?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }
}

private struct LLMImageReference: Codable {
    let url: String
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
    case imageInputUnsupported(String)
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
        case let .imageInputUnsupported(model):
            "当前模型不支持截图翻译：\(model)"
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
    var supportsImageInput: Bool { get }
    func complete(_ request: LLMRequest) async throws -> LLMResponse
}

extension LanguageModelCompleting {
    var supportsImageInput: Bool { false }
}
