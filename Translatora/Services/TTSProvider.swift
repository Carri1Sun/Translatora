import Foundation

struct TTSRequest: Equatable, Sendable {
    let text: String
    let language: TranslationLanguage
}

struct TTSResponse: Equatable, Sendable {
    let audioData: Data
    let fileExtension: String
    let model: String
}

enum TTSProviderError: LocalizedError, Equatable {
    case emptyText
    case missingAPIKey(String)
    case invalidResponse
    case service(provider: String, message: String)
    case api(provider: String, statusCode: Int, message: String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .emptyText:
            "没有可朗读的文本"
        case let .missingAPIKey(provider):
            "请先配置 \(provider) API Key"
        case .invalidResponse:
            "语音服务返回了无法解析的数据"
        case let .service(provider, message):
            "\(provider) 语音生成失败：\(message)"
        case let .api(provider, statusCode, message):
            "\(provider) 语音请求失败（\(statusCode)）：\(message)"
        case let .transport(message):
            "语音服务连接失败：\(message)"
        }
    }
}

protocol TTSProvider {
    func synthesize(_ request: TTSRequest) async throws -> TTSResponse
}

@MainActor
protocol TTSSynthesizing {
    func synthesize(_ request: TTSRequest) async throws -> TTSResponse
}
