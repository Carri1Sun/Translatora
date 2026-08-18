import Foundation

enum DeepSeekModel: String, CaseIterable, Codable, Identifiable, Sendable {
    case v4Flash = "deepseek-v4-flash"
    case v4Pro = "deepseek-v4-pro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .v4Flash:
            "DeepSeek V4 Flash"
        case .v4Pro:
            "DeepSeek V4 Pro"
        }
    }

    var summary: String {
        switch self {
        case .v4Flash:
            "响应更快，适合日常翻译"
        case .v4Pro:
            "能力更强，适合复杂文本"
        }
    }

    var supportsImageInput: Bool { false }
}

struct DeepSeekConfiguration: Equatable, Sendable {
    var apiKey: String
    var model: DeepSeekModel

    static let empty = DeepSeekConfiguration(apiKey: "", model: .v4Flash)

    var normalized: DeepSeekConfiguration {
        DeepSeekConfiguration(
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model
        )
    }
}
