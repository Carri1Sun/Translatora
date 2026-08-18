import Foundation

enum MiniMaxModel: String, CaseIterable, Codable, Identifiable, Sendable {
    case m3 = "MiniMax-M3"
    case m27 = "MiniMax-M2.7"
    case m27Highspeed = "MiniMax-M2.7-highspeed"
    case m25 = "MiniMax-M2.5"
    case m25Highspeed = "MiniMax-M2.5-highspeed"
    case m21 = "MiniMax-M2.1"
    case m21Highspeed = "MiniMax-M2.1-highspeed"
    case m2 = "MiniMax-M2"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var summary: String {
        switch self {
        case .m3:
            "最新旗舰模型，适合翻译、复杂推理与长上下文任务"
        case .m27:
            "最新标准版模型，适用于 Token Plan 标准套餐"
        case .m27Highspeed:
            "与 M2.7 效果一致、输出更快，需要支持极速模型的套餐"
        case .m25:
            "兼顾复杂任务能力与性价比"
        case .m25Highspeed:
            "M2.5 的高速版本，需要支持极速模型的套餐"
        case .m21:
            "擅长多语言与编程任务"
        case .m21Highspeed:
            "M2.1 的高速版本"
        case .m2:
            "面向编码与 Agent 工作流的基础版本"
        }
    }

    var supportsImageInput: Bool { false }
}

enum MiniMaxTTSVoice: String, CaseIterable, Codable, Identifiable, Sendable {
    case automatic
    case maleQingse = "male-qn-qingse"
    case maleJingying = "male-qn-jingying"
    case femaleShaonv = "female-shaonv"
    case femaleYujie = "female-yujie"
    case englishGracefulLady = "English_Graceful_Lady"
    case englishTrustworthyMan = "English_Trustworthy_Man"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic:
            "自动匹配翻译语言"
        case .maleQingse:
            "青涩青年（中文）"
        case .maleJingying:
            "精英青年（中文）"
        case .femaleShaonv:
            "少女（中文）"
        case .femaleYujie:
            "御姐（中文）"
        case .englishGracefulLady:
            "Graceful Lady（英文）"
        case .englishTrustworthyMan:
            "Trustworthy Man（英文）"
        }
    }

    func voiceID(for language: TranslationLanguage) -> String {
        guard self == .automatic else { return rawValue }

        return switch language {
        case .english:
            "English_Graceful_Lady"
        case .simplifiedChinese, .traditionalChinese:
            "male-qn-qingse"
        case .japanese:
            "Japanese_KindLady"
        case .korean:
            "Korean_CalmLady"
        case .french:
            "French_FemaleAnchor"
        case .german:
            "German_SweetLady"
        case .spanish:
            "Spanish_SereneWoman"
        }
    }

    var testRequest: TTSRequest {
        switch self {
        case .maleQingse, .maleJingying, .femaleShaonv, .femaleYujie:
            TTSRequest(text: "你好，这是语音测试。", language: .simplifiedChinese)
        case .automatic, .englishGracefulLady, .englishTrustworthyMan:
            TTSRequest(text: "Hello, this is a voice test.", language: .english)
        }
    }
}

struct MiniMaxConfiguration: Equatable, Sendable {
    var apiKey: String
    var model: MiniMaxModel
    var ttsVoice: MiniMaxTTSVoice = .automatic

    static let empty = MiniMaxConfiguration(
        apiKey: "",
        model: .m3,
        ttsVoice: .automatic
    )

    var normalized: MiniMaxConfiguration {
        MiniMaxConfiguration(
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model,
            ttsVoice: ttsVoice
        )
    }
}

enum LanguageModelProviderKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case deepSeek
    case miniMax
    case qwen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deepSeek:
            "DeepSeek"
        case .miniMax:
            "MiniMax（国内版）"
        case .qwen:
            "Qwen Token Plan"
        }
    }
}

enum TTSProviderKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case qwen
    case miniMax

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qwen:
            "Qwen · qwen-audio-3.0-tts-plus"
        case .miniMax:
            "MiniMax · speech-2.8-hd"
        }
    }
}
