import Foundation

enum QwenModel: String, CaseIterable, Codable, Identifiable, Sendable {
    case v38Max = "qwen3.8-max"
    case v36Flash = "qwen3.6-flash"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .v38Max:
            "Qwen3.8 Max"
        case .v36Flash:
            "Qwen3.6 Flash"
        }
    }

    var summary: String {
        switch self {
        case .v38Max:
            "旗舰模型，适合复杂文本与高质量翻译"
        case .v36Flash:
            "响应更快、额度消耗更低，适合日常翻译"
        }
    }
}

enum QwenTokenPlanRegion: String, CaseIterable, Codable, Identifiable, Sendable {
    case international
    case china

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .international:
            "国际（新加坡）"
        case .china:
            "中国内地（北京）"
        }
    }

    var baseURL: URL {
        switch self {
        case .international:
            URL(
                string: "https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1"
            )!
        case .china:
            URL(
                string: "https://token-plan.cn-beijing.maas.aliyuncs.com/compatible-mode/v1"
            )!
        }
    }

    var ttsWebSocketURL: URL {
        switch self {
        case .international:
            URL(
                string: "wss://token-plan.ap-southeast-1.maas.aliyuncs.com/api-ws/v1/inference/"
            )!
        case .china:
            URL(
                string: "wss://token-plan.cn-beijing.maas.aliyuncs.com/api-ws/v1/inference/"
            )!
        }
    }
}

struct QwenConfiguration: Equatable, Sendable {
    var apiKey: String
    var model: QwenModel
    var region: QwenTokenPlanRegion

    static let empty = QwenConfiguration(
        apiKey: "",
        model: .v38Max,
        region: .international
    )

    var normalized: QwenConfiguration {
        QwenConfiguration(
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model,
            region: region
        )
    }
}
